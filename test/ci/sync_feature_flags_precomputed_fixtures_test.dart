// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../ci/sync-feature-flags-precomputed-fixtures.dart' as importer;

void main() {
  late Directory temporary;
  late Directory root;
  late Directory source;
  late Directory destination;

  void write(String path, String text) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
  }

  String commitFixture(String name, String response) {
    final cases = Directory(
      p.join(source.path, 'precomputed-assignments/cases'),
    );
    if (cases.existsSync()) cases.deleteSync(recursive: true);
    write(
      p.join(cases.path, '$name.json'),
      '{"name":"$name","response":$response,"evaluations":[]}',
    );
    importer.git(source.path, ['add', '.']);
    final tree = utf8.decode(importer.git(source.path, ['write-tree'])).trim();
    // Synthetic objects exercise Git import without invoking commit hooks or signing.
    final commit = File(p.join(temporary.path, 'commit-object'))
      ..writeAsStringSync(
        'tree $tree\nauthor Fixture <fixture@example.invalid> 0 +0000\ncommitter Fixture <fixture@example.invalid> 0 +0000\n\nfixture\n',
      );
    return utf8
        .decode(
          importer.git(source.path, [
            'hash-object',
            '-t',
            'commit',
            '-w',
            commit.path,
          ]),
        )
        .trim();
  }

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('fixture-import-test-');
    root = Directory(p.join(temporary.path, 'consumer'))..createSync();
    source = Directory(p.join(temporary.path, 'upstream'))..createSync();
    destination = Directory(p.join(root.path, 'fixtures'));
    write(
      p.join(root.path, 'ci/feature-flags-precomputed-fixtures.json'),
      '{"destination":"fixtures","commit":"${'0' * 40}"}',
    );
    importer.git(source.path, ['init', '-q']);
    for (final path in importer.sourceFiles.keys) {
      write(p.join(source.path, path), '{}\n');
    }
  });
  tearDown(() => temporary.deleteSync(recursive: true));

  for (final response in [
    '{"number":9007199254740993.5,"overflow":1e400,"underflow":1e-400}',
    '{"text":"Unicode 🚀, escaped \\\" } ]","nested":[{"x":-0.0}]}',
    'null',
  ]) {
    test('preserves original response bytes: $response', () async {
      final sha = commitFixture('numeric', response);
      await importer.run([
        '--source',
        source.path,
        '--update',
        '--ref',
        sha,
      ], root: root);
      expect(
        File(
          p.join(destination.path, 'responses/cases/numeric.json'),
        ).readAsStringSync(),
        '$response\n',
      );
      await importer.run(['--verify'], root: root);
      await importer.run(['--source', source.path], root: root);
    });
  }

  test(
    'refresh removes deleted cases and no-op import retains provenance',
    () async {
      final oldSha = commitFixture('old', '{"value":5.0}');
      await importer.run([
        '--source',
        source.path,
        '--update',
        '--ref',
        oldSha,
      ], root: root);
      final newSha = commitFixture('new', '{"value":6.0}');
      await importer.run([
        '--source',
        source.path,
        '--update',
        '--ref',
        newSha,
      ], root: root);
      expect(
        File(p.join(destination.path, 'cases/old.json')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(destination.path, 'cases/new.json')).existsSync(),
        isTrue,
      );
      final before = importer.readSnapshot(destination);
      await importer.run([
        '--source',
        source.path,
        '--update',
        '--ref',
        newSha,
      ], root: root);
      expect(
        importer.sameSnapshot(before, importer.readSnapshot(destination)),
        isTrue,
      );
      expect(importer.provenance(before)['commit'], newSha);
    },
  );

  test(
    'check detects altered bytes and leaves destination unchanged',
    () async {
      final sha = commitFixture('numeric', '{"value":5}');
      await importer.run([
        '--source',
        source.path,
        '--update',
        '--ref',
        sha,
      ], root: root);
      write(p.join(destination.path, 'cases/numeric.json'), 'tampered');
      final before = importer.readSnapshot(destination);
      await expectLater(
        importer.run(['--verify'], root: root),
        throwsFormatException,
      );
      await expectLater(
        importer.run(['--source', source.path], root: root),
        throwsFormatException,
      );
      expect(
        importer.sameSnapshot(before, importer.readSnapshot(destination)),
        isTrue,
      );
    },
  );

  test('default run fetches the pin and --update moves only the pin', () async {
    final oldSha = commitFixture('old', '{"value":5.0}');
    await importer.run([
      '--source',
      source.path,
      '--update',
      '--ref',
      oldSha,
    ], root: root);
    final config = File(
      p.join(root.path, 'ci/feature-flags-precomputed-fixtures.json'),
    );
    expect((jsonDecode(config.readAsStringSync()) as Map)['commit'], oldSha);
    destination.deleteSync(recursive: true);
    final newSha = commitFixture('new', '{"value":6.0}');
    await importer.run(['--source', source.path], root: root);
    expect(
      importer.provenance(importer.readSnapshot(destination))['commit'],
      oldSha,
    );
    expect(
      File(p.join(destination.path, 'cases/old.json')).existsSync(),
      isTrue,
    );
    await importer.run(['--verify'], root: root);
    await importer.run([
      '--source',
      source.path,
      '--update',
      '--ref',
      newSha,
    ], root: root);
    expect((jsonDecode(config.readAsStringSync()) as Map)['commit'], newSha);
    expect(
      File(p.join(destination.path, 'cases/new.json')).existsSync(),
      isTrue,
    );
  });

  test('refuses to overwrite unrelated destination files', () async {
    final sha = commitFixture('numeric', '{}');
    await importer.run([
      '--source',
      source.path,
      '--update',
      '--ref',
      sha,
    ], root: root);
    write(p.join(destination.path, 'notes.txt'), 'keep');
    await expectLater(
      importer.run([
        '--source',
        source.path,
        '--update',
        '--ref',
        sha,
      ], root: root),
      throwsFormatException,
    );
    expect(
      File(p.join(destination.path, 'notes.txt')).readAsStringSync(),
      'keep',
    );
  });

  test('ignores Finder metadata in the destination', () async {
    final oldSha = commitFixture('old', '{}');
    await importer.run([
      '--source',
      source.path,
      '--update',
      '--ref',
      oldSha,
    ], root: root);
    write(p.join(destination.path, '.DS_Store'), 'finder');
    write(p.join(destination.path, 'cases/.DS_Store'), 'finder');
    await importer.run(['--source', source.path], root: root);
    await importer.run(['--verify'], root: root);
    final newSha = commitFixture('new', '{}');
    await importer.run([
      '--source',
      source.path,
      '--update',
      '--ref',
      newSha,
    ], root: root);
    expect(
      File(p.join(destination.path, 'cases/new.json')).existsSync(),
      isTrue,
    );
    write(p.join(destination.path, 'cases/stray.json'), '{}');
    await expectLater(
      importer.run(['--verify'], root: root),
      throwsFormatException,
    );
  });

  test('retries a failed fetch', () async {
    var calls = 0;
    await importer.fetchRevision(
      source.path,
      'main',
      backoff: Duration.zero,
      attempt: (_, _) async {
        if (++calls < importer.fetchAttempts) throw StateError('offline');
      },
    );
    expect(calls, importer.fetchAttempts);
  });

  test('fails after the last fetch attempt', () async {
    var calls = 0;
    await expectLater(
      importer.fetchRevision(
        source.path,
        'main',
        backoff: Duration.zero,
        attempt: (_, _) async {
          calls++;
          throw TimeoutException('stalled');
        },
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, importer.fetchAttempts);
  });

  test('stops a git command that exceeds its timeout', () async {
    final stopwatch = Stopwatch()..start();
    await expectLater(
      importer.gitWithTimeout(source.path, [
        '-c',
        'alias.stall=!sleep 5',
        'stall',
      ], const Duration(milliseconds: 200)),
      throwsA(isA<TimeoutException>()),
    );
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 4)));
  });

  for (final path in [
    '..',
    '.',
    '.git/fixtures',
    '../outside',
    '/tmp/outside',
  ]) {
    test('rejects unsafe destination $path', () {
      expect(() => importer.destinationFor(root, path), throwsFormatException);
    });
  }

  test('rejects symlink destination ancestors', () {
    Link(p.join(root.path, 'linked')).createSync(source.path);
    expect(
      () => importer.destinationFor(root, 'linked/fixtures'),
      throwsFormatException,
    );
  });

  test('rejects symlinks inside a snapshot', () {
    destination.createSync();
    Link(p.join(destination.path, 'linked')).createSync(source.path);
    expect(() => importer.readSnapshot(destination), throwsFormatException);
  });

  test('rejects symlink fixture entries in Git', () {
    commitFixture('numeric', '{}');
    final file = File(
      p.join(source.path, 'precomputed-assignments/cases/numeric.json'),
    );
    file.deleteSync();
    Link(file.path).createSync('../README.md');
    importer.git(source.path, ['add', '.']);
    final tree = utf8.decode(importer.git(source.path, ['write-tree'])).trim();
    final object = File(p.join(temporary.path, 'symlink-commit'))
      ..writeAsStringSync(
        'tree $tree\nauthor Fixture <fixture@example.invalid> 0 +0000\ncommitter Fixture <fixture@example.invalid> 0 +0000\n\nsymlink\n',
      );
    final sha = utf8
        .decode(
          importer.git(source.path, [
            'hash-object',
            '-t',
            'commit',
            '-w',
            object.path,
          ]),
        )
        .trim();
    expect(() => importer.snapshot(source.path, sha), throwsFormatException);
  });

  for (final args in [
    ['--ref', '../main'],
    ['--ref', '-bad'],
    ['--source'],
    ['--unknown'],
    ['--verify', '--check'],
  ]) {
    test('rejects invalid arguments $args', () async {
      await expectLater(importer.run(args, root: root), throwsFormatException);
    });
  }
}
