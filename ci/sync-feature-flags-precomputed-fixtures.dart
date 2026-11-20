// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';
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

/// Bounds one network fetch. A stalled fetch is retried.
const fetchTimeout = Duration(minutes: 2);
const fetchAttempts = 3;

/// Runs git and fails when it exceeds [timeout].
Future<void> gitWithTimeout(
  String source,
  List<String> arguments,
  Duration timeout,
) async {
  final process = await Process.start('git', ['-C', source, ...arguments]);
  final errors = process.stderr.transform(utf8.decoder).join();
  unawaited(process.stdout.drain<void>());
  final exitCode = await process.exitCode.timeout(
    timeout,
    onTimeout: () {
      process.kill();
      throw TimeoutException('git ${arguments.first} timed out', timeout);
    },
  );
  if (exitCode != 0)
    throw StateError('git ${arguments.first}: ${await errors}');
}

typedef FetchAttempt = Future<void> Function(String source, String ref);

/// Fetches [ref] from the upstream repository into [source].
///
/// Retries failed or timed-out attempts with a linear backoff.
Future<void> fetchRevision(
  String source,
  String ref, {
  FetchAttempt? attempt,
  Duration backoff = const Duration(seconds: 5),
}) async {
  attempt ??= (source, ref) => gitWithTimeout(source, [
    'fetch',
    '-q',
    '--depth=1',
    repository,
    ref,
  ], fetchTimeout);
  for (var count = 1; ; count++) {
    try {
      return await attempt(source, ref);
    } catch (error) {
      // Git failures are StateErrors; network and timeout failures are Exceptions.
      if (count == fetchAttempts ||
          (error is! Exception && error is! StateError)) {
        rethrow;
      }
      stderr.writeln('Fixture fetch attempt $count failed: $error');
    }
    await Future<void>.delayed(backoff * count);
  }
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
    // Finder writes .DS_Store files into browsed folders.
    if (entry is File && p.basename(entry.path) != '.DS_Store')
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

Future<void> run(List<String> args, {Directory? root}) async {
  var ref = 'main';
  var refGiven = false;
  String? source;
  var verifyOnly = false;
  var update = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--ref':
      case '--source':
        final option = args[i];
        if (++i == args.length)
          throw FormatException('Missing value for $option');
        if (option == '--ref') {
          ref = args[i];
          refGiven = true;
        } else {
          source = p.absolute(args[i]);
        }
      case '--verify':
        verifyOnly = true;
      case '--update':
        update = true;
      case '--help':
        stdout.writeln(
          'Usage: dart run ci/sync-feature-flags-precomputed-fixtures.dart [--update [--ref REVISION]] [--source CHECKOUT] [--verify]\n'
          'Without options, fetches the commit pinned in ci/feature-flags-precomputed-fixtures.json into the git-ignored destination.',
        );
        return;
      default:
        throw FormatException('Unknown option: ${args[i]}');
    }
  }
  if (verifyOnly && update)
    throw FormatException('Use either --verify or --update');
  validateRef(ref);
  if (refGiven && !update)
    throw FormatException(
      '--ref requires --update; the default run fetches the pin',
    );
  root ??= File.fromUri(Platform.script).parent.parent;
  final configFile = File(
    p.join(root.path, 'ci/feature-flags-precomputed-fixtures.json'),
  );
  final config = jsonDecode(configFile.readAsStringSync()) as Map;
  final pin = config['commit'];
  if (pin is! String || !RegExp(r'^[0-9a-f]{40}$').hasMatch(pin))
    throw FormatException(
      'ci/feature-flags-precomputed-fixtures.json must pin a full upstream commit SHA',
    );
  final relative = config['destination'] as String;
  if (Process.runSync('git', [
        '-C',
        root.path,
        'ls-files',
        '--error-unmatch',
        '--',
        relative,
      ]).exitCode ==
      0)
    throw FormatException(
      'Destination must not be tracked by git; add it to .gitignore',
    );
  final destination = destinationFor(root, relative);
  final before = readSnapshot(destination);
  String? current;
  if (before.isNotEmpty) {
    final metadata = provenance(before);
    current = metadata['commit'] as String;
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
    if (current != pin)
      throw FormatException(
        'Fetched snapshot ($current) does not match the pin ($pin); run without --verify',
      );
    verify(destination);
    return;
  }
  if (!update) ref = pin;
  validateRef(ref);
  Map<String, List<int>> after;
  if (!update && current == pin) {
    verify(destination);
    after = before;
  } else {
    final temporary = Directory.systemTemp.createTempSync('ffe-precompute-');
    var pinned = current == pin ? before : null;
    try {
      final fetched = source == null;
      if (fetched) {
        source = Directory(p.join(temporary.path, 'source')).path;
        Directory(source).createSync();
        git(source, ['init', '-q']);
        await fetchRevision(source, ref);
        ref = 'FETCH_HEAD';
      }
      after = snapshot(source!, ref);
      // A fresh checkout has no local snapshot, so read the pinned one to compare.
      if (update && provenance(after)['commit'] != pin && pinned == null) {
        try {
          if (fetched) {
            await fetchRevision(source, pin);
            pinned = snapshot(source, 'FETCH_HEAD');
          } else {
            pinned = snapshot(source, pin);
          }
        } on Object {
          // Without a readable pinned snapshot, the new commit counts as a change.
          pinned = null;
        }
      }
    } finally {
      temporary.deleteSync(recursive: true);
    }
    // An upstream commit that changes no imported file keeps the pin.
    if (pinned != null &&
        provenance(after)['commit'] != pin &&
        sameSnapshot(pinned, after, includeProvenance: false)) {
      after = pinned;
    }
    if (!sameSnapshot(before, after)) replaceSnapshot(destination, after);
  }
  final commit = provenance(after)['commit'] as String;
  final changed = commit != pin;
  if (changed) {
    config['commit'] = commit;
    configFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(config)}\n',
    );
  }
  final count = (jsonDecode(utf8.decode(after['index.json']!)) as List).length;
  stdout.writeln(
    'Feature flags precomputed fixtures: $commit; $count files; pin changed=$changed',
  );
  final output = Platform.environment['GITHUB_OUTPUT'];
  if (output != null)
    File(output).writeAsStringSync(
      'changed=$changed\nsource_commit=$commit\nfixture_count=$count\n',
      mode: FileMode.append,
    );
}

Future<void> main(List<String> args) => run(args);
