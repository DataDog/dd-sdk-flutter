// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const repository = 'https://github.com/DataDog/ffe-system-test-data.git';
const prefix = 'precomputed-assignments/';
const sourceFiles = {
  'schemas/precomputed-assignment.schema.json': 'schema.json',
  'precomputed-assignments/README.md': 'README.md',
  'LICENSE': 'LICENSE',
  'NOTICE': 'NOTICE',
};

List<int> git(String source, List<String> arguments) {
  final result = Process.runSync('git', [
    '-C',
    source,
    ...arguments,
  ], stdoutEncoding: null);
  if (result.exitCode != 0)
    throw StateError('git ${arguments.first}: ${result.stderr}');
  return result.stdout as List<int>;
}

void validateRef(String ref) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._/-]*$').hasMatch(ref) ||
      ref.contains('..')) {
    throw FormatException('Invalid fixture revision');
  }
}

// Find JSON value boundaries while retaining the original number tokens.
int valueEnd(String text, int start) {
  if (text[start] == '"') {
    var i = start + 1;
    while (i < text.length) {
      if (text[i] == r'\') {
        i += 2;
      } else if (text[i++] == '"') {
        return i;
      }
    }
  } else if (text[start] == '{' || text[start] == '[') {
    final close = text[start] == '{' ? '}' : ']';
    var i = start + 1;
    while (i < text.length) {
      if (text[i] == close) return i + 1;
      if (text[i] == '"' || text[i] == '{' || text[i] == '[') {
        i = valueEnd(text, i);
      } else {
        i++;
      }
    }
  } else {
    var i = start;
    while (i < text.length && !RegExp(r'[\s,}\]]').hasMatch(text[i])) {
      i++;
    }
    if (i > start) return i;
  }
  throw FormatException('Invalid JSON value');
}

List<int> responseBytes(List<int> bytes) {
  final text = utf8.decode(bytes);
  if (jsonDecode(text) is! Map)
    throw FormatException('Fixture must be an object');
  var i = text.indexOf('{') + 1;
  int whitespace(int offset) {
    while (offset < text.length && text[offset].trim().isEmpty) {
      offset++;
    }
    return offset;
  }

  while (true) {
    i = whitespace(i);
    if (text[i] == '}') throw FormatException('Fixture is missing response');
    final keyEnd = valueEnd(text, i);
    final key = jsonDecode(text.substring(i, keyEnd));
    i = whitespace(keyEnd);
    if (text[i] != ':') throw FormatException('Invalid fixture object');
    final start = whitespace(i + 1);
    i = valueEnd(text, start);
    if (key == 'response') return utf8.encode('${text.substring(start, i)}\n');
    i = whitespace(i);
    if (text[i] == ',') i++;
  }
}

List<int> jsonBytes(Object value) =>
    utf8.encode('${const JsonEncoder.withIndent('  ').convert(value)}\n');

Map<String, List<int>> snapshot(String source, String ref) {
  validateRef(ref);
  final sha = utf8
      .decode(git(source, ['rev-parse', '--verify', '$ref^{commit}']))
      .trim();
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(sha))
    throw FormatException('Expected a full source commit SHA');
  final result = <String, List<int>>{};
  for (final entry
      in utf8
          .decode(git(source, ['ls-tree', '-rz', '--full-tree', sha]))
          .split('\x00')) {
    if (entry.isEmpty) continue;
    final tab = entry.indexOf('\t');
    final path = entry.substring(tab + 1);
    final target = path.startsWith('${prefix}cases/') && path.endsWith('.json')
        ? path.substring(prefix.length)
        : sourceFiles[path];
    if (target == null) continue;
    final fields = entry.substring(0, tab).split(' ');
    if (fields[0] != '100644' || fields[1] != 'blob')
      throw FormatException('Fixture entries must be ordinary files: $path');
    result[target] = git(source, ['cat-file', 'blob', fields[2]]);
  }
  final cases = result.keys.where((path) => path.startsWith('cases/')).toList()
    ..sort();
  if (cases.isEmpty || !sourceFiles.values.every(result.containsKey))
    throw FormatException('Missing or empty precomputed fixture corpus');
  for (final path in cases) {
    final data = jsonDecode(utf8.decode(result[path]!));
    if (data is! Map || data['name'] != p.basenameWithoutExtension(path))
      throw FormatException('Invalid fixture identity: $path');
    if (data['evaluations'] is! List)
      throw FormatException('Missing evaluations: $path');
    result['responses/$path'] = responseBytes(result[path]!);
  }
  result['index.json'] = jsonBytes(cases);
  result['SOURCE.json'] = jsonBytes({
    'repository': repository,
    'commit': sha,
    'files': hashes(result),
  });
  return result;
}

Map<String, String> hashes(Map<String, List<int>> content) => {
  for (final path in content.keys.toList()..sort())
    path: sha256.convert(content[path]!).toString(),
};

Map<String, List<int>> readSnapshot(Directory directory) {
  if (!directory.existsSync()) return {};
  final result = <String, List<int>>{};
  for (final entry in directory.listSync(recursive: true, followLinks: false)) {
    if (entry is Link)
      throw FormatException('Snapshot must not contain symbolic links');
    if (entry is File)
      result[p.posix.joinAll(
        p.split(p.relative(entry.path, from: directory.path)),
      )] = entry
          .readAsBytesSync();
  }
  return result;
}

Map<String, dynamic> provenance(Map<String, List<int>> content) {
  final metadata = jsonDecode(
    utf8.decode(
      content['SOURCE.json'] ??
          (throw FormatException('Missing snapshot provenance')),
    ),
  );
  if (metadata is! Map<String, dynamic> ||
      metadata['repository'] != repository ||
      metadata['commit'] is! String ||
      !RegExp(r'^[0-9a-f]{40}$').hasMatch(metadata['commit'] as String) ||
      metadata['files'] is! Map) {
    throw FormatException('Invalid source provenance');
  }
  return metadata;
}

void verify(Directory destination) {
  final content = readSnapshot(destination);
  final metadata = provenance(content);
  content.remove('SOURCE.json');
  final actual = hashes(content);
  final expected = metadata['files'] as Map;
  if (actual.length != expected.length ||
      !actual.entries.every((e) => expected[e.key] == e.value))
    throw FormatException(
      'Snapshot content differs from its recorded checksums',
    );
  final cases =
      content.keys
          .where((path) => path.startsWith('cases/') && path.endsWith('.json'))
          .toList()
        ..sort();
  if (cases.isEmpty ||
      jsonEncode(jsonDecode(utf8.decode(content['index.json']!))) !=
          jsonEncode(cases))
    throw FormatException('Missing, empty, or stale fixture index');
  stdout.writeln('Verified ${cases.length} fixtures at ${metadata['commit']}');
}

Directory destinationFor(Directory root, String relative) {
  if (p.isAbsolute(relative) ||
      p.split(relative).any((part) => part == '..' || part == '.git'))
    throw FormatException('Destination must be inside the repository');
  final base = root.resolveSymbolicLinksSync();
  final destination = p.normalize(p.join(base, relative));
  if (!p.isWithin(base, destination))
    throw FormatException(
      'Destination must be a dedicated directory inside the repository',
    );
  var current = base;
  for (final part in p.split(p.relative(destination, from: base))) {
    current = p.join(current, part);
    final type = FileSystemEntity.typeSync(current, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory)
      throw FormatException(
        'Destination must contain only directories, not symbolic links',
      );
  }
  return Directory(destination);
}

bool sameSnapshot(
  Map<String, List<int>> left,
  Map<String, List<int>> right, {
  bool includeProvenance = true,
}) {
  final a = {...left};
  final b = {...right};
  if (!includeProvenance) {
    a.remove('SOURCE.json');
    b.remove('SOURCE.json');
  }
  return jsonEncode(hashes(a)) == jsonEncode(hashes(b));
}

void replaceSnapshot(Directory destination, Map<String, List<int>> content) {
  destination.parent.createSync(recursive: true);
  final temporary = destination.parent.createTempSync('.precompute-');
  var preserveBackup = false;
  try {
    final staged = Directory(p.join(temporary.path, 'snapshot'))..createSync();
    for (final entry in content.entries) {
      final file = File(p.join(staged.path, entry.key));
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(entry.value);
    }
    final backup = p.join(temporary.path, 'previous');
    final existed = destination.existsSync();
    if (existed) destination.renameSync(backup);
    try {
      staged.renameSync(destination.path);
    } catch (_) {
      if (existed) {
        preserveBackup = true;
        Directory(backup).renameSync(destination.path);
        preserveBackup = false;
      }
      rethrow;
    }
  } finally {
    if (!preserveBackup) temporary.deleteSync(recursive: true);
  }
}

void run(List<String> args, {Directory? root}) {
  var ref = 'main';
  String? source;
  var verifyOnly = false;
  var check = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--ref':
      case '--source':
        final option = args[i];
        if (++i == args.length)
          throw FormatException('Missing value for $option');
        if (option == '--ref') {
          ref = args[i];
        } else {
          source = p.absolute(args[i]);
        }
      case '--verify':
        verifyOnly = true;
      case '--check':
        check = true;
      case '--help':
        stdout.writeln(
          'Usage: dart run ci/sync-precomputed-fixtures.dart [--ref REVISION] [--source CHECKOUT] [--verify | --check]',
        );
        return;
      default:
        throw FormatException('Unknown option: ${args[i]}');
    }
  }
  if (verifyOnly && check)
    throw FormatException('Use either --verify or --check');
  validateRef(ref);
  root ??= File.fromUri(Platform.script).parent.parent;
  final config =
      jsonDecode(
            File(
              p.join(root.path, 'ci/precomputed-fixtures.json'),
            ).readAsStringSync(),
          )
          as Map;
  final destination = destinationFor(root, config['destination'] as String);
  final before = readSnapshot(destination);
  if (before.isNotEmpty) {
    final metadata = provenance(before);
    if (before.keys.any(
      (path) =>
          path != 'SOURCE.json' &&
          !(metadata['files'] as Map).containsKey(path),
    ))
      throw FormatException(
        'Destination contains files outside the previous snapshot',
      );
  }
  if (verifyOnly) {
    verify(destination);
    return;
  }
  if (check) ref = provenance(before)['commit'] as String;
  final temporary = Directory.systemTemp.createTempSync('ffe-precompute-');
  try {
    if (source == null) {
      source = Directory(p.join(temporary.path, 'source')).path;
      Directory(source).createSync();
      git(source, ['init', '-q']);
      git(source, ['fetch', '-q', '--depth=1', repository, ref]);
      ref = 'FETCH_HEAD';
    }
    final after = snapshot(source, ref);
    final changed = !sameSnapshot(before, after, includeProvenance: false);
    if (check) {
      if (!sameSnapshot(before, after))
        throw FormatException(
          'Snapshot differs from its recorded source commit',
        );
    } else if (changed) {
      replaceSnapshot(destination, after);
    }
    final selected = check || !changed ? before : after;
    final metadata = provenance(selected);
    final count =
        (jsonDecode(utf8.decode(selected['index.json']!)) as List).length;
    stdout.writeln(
      'FFE precomputed fixtures: ${metadata['commit']}; $count files; changed=$changed',
    );
    final output = Platform.environment['GITHUB_OUTPUT'];
    if (output != null)
      File(output).writeAsStringSync(
        'changed=$changed\nsource_commit=${metadata['commit']}\nfixture_count=$count\n',
        mode: FileMode.append,
      );
  } finally {
    temporary.deleteSync(recursive: true);
  }
}

void main(List<String> args) => run(args);
