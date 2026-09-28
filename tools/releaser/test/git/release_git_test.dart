// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:releaser/git/release_git.dart';
import 'package:test/test.dart';

import '../support/fixture_repo.dart';
import '../support/test_temp.dart';

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

  group('pushTag', () {
    // A local bare repo standing in for the real remote -- exercises the
    // actual `git push` rather than mocking it, the same way the rest of
    // this file tests real git plumbing; no network involved.
    late Directory bareRemote;

    setUp(() async {
      bareRemote = await createTestTempDir('release_git_test_remote_');
      await Process.run('git', ['init', '-q', '--bare', bareRemote.path]);
      await Process.run('git', [
        'remote',
        'add',
        'origin',
        bareRemote.path,
      ], workingDirectory: fixture.root.path);
    });

    tearDown(() => bareRemote.delete(recursive: true));

    test('creates a tag at the given commit and pushes it', () async {
      final gitDir = await fixture.gitDir;
      final sha = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();

      await pushTag(gitDir, 'datadog_dio/v1.0.0-test', sha, logger);

      final result = await Process.run('git', [
        'rev-parse',
        'datadog_dio/v1.0.0-test^{commit}',
      ], workingDirectory: bareRemote.path);
      expect((result.stdout as String).trim(), sha);
    });

    test('tags exactly the given commit, not the current branch tip', () async {
      final gitDir = await fixture.gitDir;
      final firstSha = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();

      await fixture.commit('chore: a second commit');

      await pushTag(gitDir, 'datadog_dio/v1.0.0-test', firstSha, logger);

      final result = await Process.run('git', [
        'rev-parse',
        'datadog_dio/v1.0.0-test^{commit}',
      ], workingDirectory: bareRemote.path);
      expect((result.stdout as String).trim(), firstSha);
    });
  });

  group('pushBranchAt', () {
    late Directory bareRemote;

    setUp(() async {
      bareRemote = await createTestTempDir('release_git_test_remote_');
      await Process.run('git', ['init', '-q', '--bare', bareRemote.path]);
      await Process.run('git', [
        'remote',
        'add',
        'origin',
        bareRemote.path,
      ], workingDirectory: fixture.root.path);
    });

    tearDown(() => bareRemote.delete(recursive: true));

    test(
      'pushes the given commit as a new branch, not the current tip',
      () async {
        final gitDir = await fixture.gitDir;
        final firstSha = (await gitDir.runCommand([
          'rev-parse',
          'HEAD',
        ])).stdout.toString().trim();

        await fixture.commit('chore: a second commit');

        await pushBranchAt(
          gitDir,
          'release-content/test-branch',
          firstSha,
          logger,
        );

        final result = await Process.run('git', [
          'rev-parse',
          'release-content/test-branch',
        ], workingDirectory: bareRemote.path);
        expect((result.stdout as String).trim(), firstSha);
      },
    );

    test('force-moves an existing branch to a new commit', () async {
      final gitDir = await fixture.gitDir;
      final firstSha = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();
      await pushBranchAt(
        gitDir,
        'release-content/test-branch',
        firstSha,
        logger,
      );

      await fixture.commit('chore: amended content');
      final secondSha = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();
      await pushBranchAt(
        gitDir,
        'release-content/test-branch',
        secondSha,
        logger,
        force: true,
      );

      final result = await Process.run('git', [
        'rev-parse',
        'release-content/test-branch',
      ], workingDirectory: bareRemote.path);
      expect((result.stdout as String).trim(), secondSha);
    });
  });

  group('contentBranchNameFor', () {
    test('swaps the release-prep prefix for release-content', () {
      expect(
        contentBranchNameFor('release-prep/20260925-abc123'),
        'release-content/20260925-abc123',
      );
    });

    test('throws for a branch with no release-prep prefix', () {
      expect(() => contentBranchNameFor('v4'), throwsStateError);
    });
  });

  group('changedFilesAgainst', () {
    test('lists a modified tracked file and a new untracked file', () async {
      fixture.writeFile('packages/datadog_dio/CHANGELOG.md', '# Changes\n');
      fixture.writeFile('packages/datadog_dio/NEW_FILE.md', 'hi');
      final gitDir = await fixture.gitDir;

      final files = await changedFilesAgainst(gitDir, 'HEAD', logger);

      expect(
        files,
        containsAll([
          'packages/datadog_dio/CHANGELOG.md',
          'packages/datadog_dio/NEW_FILE.md',
        ]),
      );
    });

    test('is empty with no working tree changes', () async {
      final gitDir = await fixture.gitDir;

      expect(await changedFilesAgainst(gitDir, 'HEAD', logger), isEmpty);
    });
  });

  group('stashPush/stashApply/stashDrop', () {
    test('round-trips a working tree edit through a stash', () async {
      fixture.writeFile('packages/datadog_dio/CHANGELOG.md', '# Changes\n');
      final gitDir = await fixture.gitDir;

      final stashSha = await stashPush(gitDir, logger, 'test-stash');
      expect(await isWorkingTreeClean(gitDir, logger), isTrue);

      await stashApply(gitDir, logger, stashSha);
      expect(await isWorkingTreeClean(gitDir, logger), isFalse);

      await stashDrop(gitDir, logger, stashSha);
      final list = await gitDir.runCommand(['stash', 'list']);
      expect((list.stdout as String).trim(), isEmpty);
    });

    test('stashDrop is a no-op once the stash is already gone', () async {
      fixture.writeFile('packages/datadog_dio/CHANGELOG.md', '# Changes\n');
      final gitDir = await fixture.gitDir;
      final stashSha = await stashPush(gitDir, logger, 'test-stash');
      await stashDrop(gitDir, logger, stashSha);

      await stashDrop(gitDir, logger, stashSha);
    });
  });

  group('amendCommit', () {
    test('rewrites HEAD with staged changes and returns the new SHA', () async {
      final gitDir = await fixture.gitDir;
      final originalSha = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();

      fixture.writeFile('packages/datadog_dio/CHANGELOG.md', '# Changes\n');
      await stageAll(gitDir, logger);
      final amendedSha = await amendCommit(gitDir, logger);

      expect(amendedSha, isNot(originalSha));
      // Amending replaces the commit rather than adding a child -- the
      // repo still has exactly one commit, just under a new SHA.
      final count = (await gitDir.runCommand([
        'rev-list',
        '--count',
        'HEAD',
      ])).stdout.toString().trim();
      expect(count, '1');
    });
  });

  group('rebaseOnto', () {
    test('replays commit B onto an amended commit A', () async {
      final gitDir = await fixture.gitDir;
      final commitA = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();
      await fixture.commit('chore: commit B');
      final workingBranch = (await gitDir.currentBranch()).branchName;

      await checkoutRef(gitDir, commitA, logger);
      fixture.writeFile('packages/datadog_dio/CHANGELOG.md', '# Fixed\n');
      await stageAll(gitDir, logger);
      final amendedA = await amendCommit(gitDir, logger);

      await rebaseOnto(gitDir, amendedA, commitA, workingBranch, logger);

      expect((await gitDir.currentBranch()).branchName, workingBranch);
      expect(await isAncestor(gitDir, amendedA, 'HEAD', logger), isTrue);
      expect(await commitCountBetween(gitDir, amendedA, 'HEAD', logger), 1);
      final changelog = File(
        p.join(fixture.root.path, 'packages/datadog_dio/CHANGELOG.md'),
      );
      expect(changelog.readAsStringSync(), '# Fixed\n');
    });
  });

  group('commitCountBetween', () {
    test('counts commits strictly between the two refs', () async {
      final gitDir = await fixture.gitDir;
      final firstSha = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();
      await fixture.commit('chore: a second commit');
      await fixture.commit('chore: a third commit');

      expect(await commitCountBetween(gitDir, firstSha, 'HEAD', logger), 2);
    });
  });

  group('forcePushBranch', () {
    late Directory bareRemote;

    setUp(() async {
      bareRemote = await createTestTempDir('release_git_test_remote_');
      await Process.run('git', ['init', '-q', '--bare', bareRemote.path]);
      await Process.run('git', [
        'remote',
        'add',
        'origin',
        bareRemote.path,
      ], workingDirectory: fixture.root.path);
    });

    tearDown(() => bareRemote.delete(recursive: true));

    test('moves an already-pushed branch to its new local tip', () async {
      final gitDir = await fixture.gitDir;
      await pushBranch(gitDir, 'main', logger);

      await fixture.commit('chore: amended locally');
      final newSha = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();

      await forcePushBranch(gitDir, 'main', logger);

      final result = await Process.run('git', [
        'rev-parse',
        'main',
      ], workingDirectory: bareRemote.path);
      expect((result.stdout as String).trim(), newSha);
    });
  });

  group('isAncestor', () {
    test('is true for HEAD~1 relative to HEAD', () async {
      final gitDir = await fixture.gitDir;
      final firstSha = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();
      await fixture.commit('chore: a second commit');

      expect(await isAncestor(gitDir, firstSha, 'HEAD', logger), isTrue);
    });

    test('is false for a commit not reachable from ref', () async {
      final gitDir = await fixture.gitDir;
      await fixture.commit('chore: a second commit');
      final secondSha = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();

      await gitDir.runCommand(['checkout', '-b', 'side-branch', 'HEAD~1']);
      await fixture.commit('chore: a divergent commit');

      expect(await isAncestor(gitDir, secondSha, 'HEAD', logger), isFalse);
    });
  });
}
