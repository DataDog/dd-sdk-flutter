// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
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
      await Process.run('git', [
        'init',
        '-q',
        '--bare',
        bareRemote.path,
      ]);
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

    test('tags exactly the given commit, not the current branch tip',
        () async {
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
      await Process.run('git', [
        'init',
        '-q',
        '--bare',
        bareRemote.path,
      ]);
      await Process.run('git', [
        'remote',
        'add',
        'origin',
        bareRemote.path,
      ], workingDirectory: fixture.root.path);
    });

    tearDown(() => bareRemote.delete(recursive: true));

    test('pushes the given commit as a new branch, not the current tip',
        () async {
      final gitDir = await fixture.gitDir;
      final firstSha = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();

      await fixture.commit('chore: a second commit');

      await pushBranchAt(gitDir, 'release-content/test-branch', firstSha, logger);

      final result = await Process.run('git', [
        'rev-parse',
        'release-content/test-branch',
      ], workingDirectory: bareRemote.path);
      expect((result.stdout as String).trim(), firstSha);
    });

    test('force-moves an existing branch to a new commit', () async {
      final gitDir = await fixture.gitDir;
      final firstSha = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();
      await pushBranchAt(gitDir, 'release-content/test-branch', firstSha, logger);

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
