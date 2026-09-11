// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:releaser/git_history.dart';
import 'package:test/test.dart';

import 'support/fixture_repo.dart';

void main() {
  late FixtureRepo fixture;
  var fileCounter = 0;

  setUp(() async {
    fixture = await FixtureRepo.create();
    fileCounter = 0;
  });

  tearDown(() => fixture.delete());

  // commitsSince filters by pathspec, which means it filters by real
  // changes -- an --allow-empty commit with no file touched wouldn't show
  // up, unlike in real history.
  Future<void> commitTouchingPathspec(
    String subject, {
    List<String> body = const [],
  }) {
    fileCounter++;
    fixture.writeFile('CHANGES-$fileCounter', 'work');
    return fixture.commit(subject, body: body);
  }

  group('commitsSince', () {
    test('pairs each commit with its own SHA, newest first', () async {
      final gitDir = await fixture.gitDir;
      await commitTouchingPathspec('feat: add a thing (#42)');
      await commitTouchingPathspec('fix: correct a bug');

      final records = await commitsSince(gitDir, pathspec: '.');

      expect(records, hasLength(3)); // plus the fixture's initial commit
      expect(records[0].message, 'fix: correct a bug');
      expect(records[1].message, 'feat: add a thing (#42)');
      expect(records.map((r) => r.sha).toSet(), hasLength(3));
      for (final record in records) {
        expect(record.sha, hasLength(40));
      }
    });

    test('a null sinceSha walks the entire history', () async {
      final gitDir = await fixture.gitDir;
      await commitTouchingPathspec('feat: add a thing');

      final records = await commitsSince(gitDir, pathspec: '.');

      expect(records, hasLength(2));
    });

    test('sinceSha excludes everything up to and including it', () async {
      final gitDir = await fixture.gitDir;
      await commitTouchingPathspec('feat: an earlier thing');
      final baseline = (await commitsSince(gitDir, pathspec: '.')).first;
      await commitTouchingPathspec('feat: add a thing');
      await commitTouchingPathspec('fix: correct a bug');

      final records = await commitsSince(
        gitDir,
        pathspec: '.',
        sinceSha: baseline.sha,
      );

      expect(records, hasLength(2));
      expect(records.any((r) => r.sha == baseline.sha), isFalse);
    });

    test(
      'preserves a multi-line body, e.g. a BREAKING CHANGE footer',
      () async {
        final gitDir = await fixture.gitDir;
        await commitTouchingPathspec(
          'feat: add a thing',
          body: ['BREAKING CHANGE: the old thing is gone'],
        );

        final record = (await commitsSince(gitDir, pathspec: '.')).first;

        expect(
          record.message,
          contains('BREAKING CHANGE: the old thing is gone'),
        );
      },
    );
  });
}
