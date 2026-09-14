// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:logging/logging.dart';
import 'package:releaser/git/release_git.dart';
import 'package:test/test.dart';

import '../support/fixture_repo.dart';

void main() {
  late FixtureRepo fixture;
  final logger = Logger('release_git_test');

  setUp(() async {
    fixture = await FixtureRepo.create();
  });

  tearDown(() => fixture.delete());

  group('isWorkingTreeClean', () {
    test('is true right after a commit', () async {
      final gitDir = await fixture.gitDir;

      expect(await isWorkingTreeClean(gitDir, logger), isTrue);
    });

    test('is false with an unstaged modification', () async {
      fixture.writeFile('packages/datadog_dio/pubspec.yaml', 'name: changed\n');
      final gitDir = await fixture.gitDir;

      expect(await isWorkingTreeClean(gitDir, logger), isFalse);
    });

    test('is false with an untracked file', () async {
      fixture.writeFile('packages/datadog_dio/NEW_FILE.md', 'hi');
      final gitDir = await fixture.gitDir;

      expect(await isWorkingTreeClean(gitDir, logger), isFalse);
    });
  });
}
