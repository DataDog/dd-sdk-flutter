// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:releaser/git/release_git.dart';
import 'package:releaser/git/release_publisher.dart';
import 'package:test/test.dart';

import '../support/fixture_repo.dart';
import '../support/test_temp.dart';

void main() {
  final logger = Logger('release_publisher_test');
  late FixtureRepo fixture;
  late Directory bareRemote;
  late Directory scripts;

  setUp(() async {
    fixture = await FixtureRepo.create();
    bareRemote = await createTestTempDir('release_publisher_test_remote_');
    scripts = await createTestTempDir('release_publisher_test_scripts_');
    await Process.run('git', ['init', '-q', '--bare', bareRemote.path]);
    await Process.run('git', [
      'remote',
      'add',
      'origin',
      bareRemote.path,
    ], workingDirectory: fixture.root.path);
  });

  tearDown(() async {
    await fixture.delete();
    await bareRemote.delete(recursive: true);
    await scripts.delete(recursive: true);
  });

  /// A stand-in for `commit-headless`: runs [body] in the checkout and prints
  /// whatever it echoes.
  String fakeBinary(String body) {
    final file = File('${scripts.path}/commit-headless')
      ..writeAsStringSync('#!/bin/sh\n$body\n');
    Process.runSync('chmod', ['+x', file.path]);
    return file.path;
  }

  ReleasePublisher publisher(String binary) => ReleasePublisher(
    commitHeadless: true,
    repoSlug: 'owner/repo',
    commitHeadlessBinary: binary,
  );

  Future<String> pushNewBranch(ReleasePublisher publisher) async {
    final gitDir = await fixture.gitDir;
    await gitDir.runCommand(['checkout', '-b', 'release-content/x']);
    final base = (await gitDir.runCommand([
      'rev-parse',
      'HEAD',
    ])).stdout.toString().trim();
    fixture.writeFile('a.txt', 'a');
    await fixture.commit('chore: a');
    return publisher.pushNewBranch(gitDir, 'release-content/x', base, logger);
  }

  test('moves the local branch onto the commit commit-headless created, and '
      'returns it', () async {
    // Re-creates HEAD as a different commit on the remote, like the real tool.
    final binary = fakeBinary('''
git commit -q --amend --no-edit --date="2000-01-01T00:00:00" --allow-empty
SHA=\$(git rev-parse HEAD)
git push -q origin "\$SHA:refs/heads/release-content/x"
git reset -q --hard HEAD~1
echo "\$SHA"
''');

    final sha = await pushNewBranch(publisher(binary));

    final gitDir = await fixture.gitDir;
    expect((await gitDir.currentBranch()).sha, sha);
    final remote = await Process.run('git', [
      'rev-parse',
      'release-content/x',
    ], workingDirectory: bareRemote.path);
    expect((remote.stdout as String).trim(), sha);
  });

  test('throws when commit-headless exits non-zero', () async {
    final binary = fakeBinary('echo boom >&2\nexit 1');

    await expectLater(
      pushNewBranch(publisher(binary)),
      throwsA(isA<GitReleaseActionError>()),
    );
  });

  test('throws when commit-headless does not print a commit SHA', () async {
    final binary = fakeBinary('echo "nothing to push"');

    await expectLater(
      pushNewBranch(publisher(binary)),
      throwsA(
        isA<GitReleaseActionError>().having(
          (e) => e.message,
          'message',
          contains('did not print a commit SHA'),
        ),
      ),
    );
  });

  test('throws when the remote branch is not at the reported commit', () async {
    // Reports a SHA it never pushed (the unsigned local commit), the way a
    // silently skipped --reset would have left things.
    final binary = fakeBinary('''
SHA=\$(git rev-parse HEAD)
git push -q origin "HEAD~1:refs/heads/release-content/x"
echo "\$SHA"
''');

    await expectLater(
      pushNewBranch(publisher(binary)),
      throwsA(
        isA<GitReleaseActionError>().having(
          (e) => e.message,
          'message',
          contains('is at'),
        ),
      ),
    );
  });

  group('mergeRemoteBranchInto', () {
    /// Leaves `release-prep/x` checked out with a commit of its own, and
    /// `origin/main` one commit ahead of their common base, both touching
    /// `c.txt` when [conflicting].
    Future<void> setUpDivergedBranches({required bool conflicting}) async {
      final gitDir = await fixture.gitDir;
      final start = (await gitDir.currentBranch()).branchName;
      await gitDir.runCommand(['checkout', '-b', 'mainline']);
      fixture.writeFile(conflicting ? 'c.txt' : 'main-only.txt', 'theirs');
      await fixture.commit('chore: on main');
      await gitDir.runCommand(['push', 'origin', 'mainline:refs/heads/main']);
      await gitDir.runCommand(['fetch', 'origin']);
      await gitDir.runCommand(['checkout', start]);
      await gitDir.runCommand(['checkout', '-b', 'release-prep/x']);
      fixture.writeFile('c.txt', 'mine');
      await fixture.commit('chore: on release-prep');
    }

    test('merges plainly when nothing conflicts', () async {
      await setUpDivergedBranches(conflicting: false);
      final gitDir = await fixture.gitDir;

      await ReleasePublisher(
        commitHeadless: false,
      ).mergeRemoteBranchInto(gitDir, 'release-prep/x', 'main', logger);

      expect(await isMergeCommit(gitDir, 'HEAD'), isTrue);
      expect(File('${fixture.root.path}/main-only.txt').existsSync(), isTrue);
    });

    test('on a conflict keeps this branch\'s side and still records the '
        'merge', () async {
      await setUpDivergedBranches(conflicting: true);
      final gitDir = await fixture.gitDir;

      await ReleasePublisher(
        commitHeadless: false,
      ).mergeRemoteBranchInto(gitDir, 'release-prep/x', 'main', logger);

      expect(await isMergeCommit(gitDir, 'HEAD'), isTrue);
      expect(File('${fixture.root.path}/c.txt').readAsStringSync(), 'mine');
      expect(await isAncestor(gitDir, 'origin/main', 'HEAD', logger), isTrue);
    });

    test('through the API, throws with an explanation when GitHub refuses '
        'the merge', () async {
      await setUpDivergedBranches(conflicting: true);
      final gitDir = await fixture.gitDir;
      final gh = fakeBinary('echo "Merge conflict" >&2\nexit 1');

      await expectLater(
        ReleasePublisher(
          commitHeadless: true,
          repoSlug: 'owner/repo',
          ghBinary: gh,
        ).mergeRemoteBranchInto(gitDir, 'release-prep/x', 'main', logger),
        throwsA(
          isA<GitReleaseActionError>().having(
            (e) => e.message,
            'message',
            allOf(contains('Merge conflict'), contains('without')),
          ),
        ),
      );
    });

    test('through the API, moves the local branch onto the commit GitHub '
        'created', () async {
      await setUpDivergedBranches(conflicting: false);
      final gitDir = await fixture.gitDir;
      // Stands in for GitHub: adds a commit on top of the pushed branch.
      final gh = fakeBinary('''
git commit -q --allow-empty -m "Merge main into release-prep/x"
git push -q origin HEAD:refs/heads/release-prep/x
git reset -q --hard HEAD~1
''');

      final tip = await ReleasePublisher(
        commitHeadless: true,
        repoSlug: 'owner/repo',
        ghBinary: gh,
      ).mergeRemoteBranchInto(gitDir, 'release-prep/x', 'main', logger);

      final remote = await Process.run('git', [
        'rev-parse',
        'release-prep/x',
      ], workingDirectory: bareRemote.path);
      expect(tip, (remote.stdout as String).trim());
      expect((await gitDir.currentBranch()).sha, tip);
    });
  });
}
