// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:git/git.dart';
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
  String fakeBinary(String body, {String name = 'commit-headless'}) {
    final file = File('${scripts.path}/$name')
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

  test(
    'gives commit-headless the commits to push on stdin, oldest first',
    () async {
      final recorded = '${scripts.path}/stdin.txt';
      final binary = fakeBinary('''
cat > "$recorded"
SHA=\$(git rev-parse HEAD)
git push -q origin "\$SHA:refs/heads/release-content/x"
echo "\$SHA"
''');

      final sha = await pushNewBranch(publisher(binary));

      expect(File(recorded).readAsStringSync().trim(), sha);
    },
  );

  test('refuses to push when HEAD has no commits on top of the base', () async {
    final gitDir = await fixture.gitDir;
    final base = (await gitDir.currentBranch()).sha;
    final binary = fakeBinary('echo should-not-run');

    await expectLater(
      publisher(
        binary,
      ).pushNewBranch(gitDir, 'release-content/x', base, logger),
      throwsA(
        isA<GitReleaseActionError>().having(
          (e) => e.message,
          'message',
          contains('Nothing to push'),
        ),
      ),
    );
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

    test('through the API, throws when GitHub refuses a merge that does not '
        'conflict', () async {
      await setUpDivergedBranches(conflicting: false);
      final gitDir = await fixture.gitDir;
      final gh = fakeBinary('echo "boom" >&2\nexit 1');

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
            contains('through the GitHub API failed: boom'),
          ),
        ),
      );
    });

    // Stands in for GitHub's REST API: refuses a conflicting merge like the
    // real one, and otherwise merges for real. Records every call in
    // `gh.log`.
    String fakeGitHub({
      String verified = 'true',
      bool refuseResolutionMerge = false,
    }) => fakeBinary(
      r'''
echo "$*" >> "@LOG@"
for a in "$@"; do
  case "$a" in
    tree=*) tree=${a#tree=} ;;
    parents*=*) parent=${a#*=} ;;
    ref=*) ref=${a#ref=} ;;
    sha=*) sha=${a#sha=} ;;
    head=*) head=${a#head=} ;;
  esac
done
case "$*" in
  *git/commits*)
    echo "$(git commit-tree "$tree" -p "$parent" -m resolution) @VERIFIED@"
    ;;
  *git/refs*)
    git push -q origin "$sha:$ref"
    ;;
  *merges*)
    if [ "@REFUSE@" = true ] && [ "$head" != main ]; then
      echo "boom" >&2
      exit 1
    fi
    git fetch -q origin "$head"
    if ! git merge -q --no-edit FETCH_HEAD >/dev/null 2>&1; then
      git merge --abort
      echo "Merge conflict" >&2
      exit 1
    fi
    git push -q origin HEAD:refs/heads/release-prep/x
    git reset -q --hard HEAD~1
    ;;
esac
'''
          .replaceAll('@LOG@', '${scripts.path}/gh.log')
          .replaceAll('@VERIFIED@', verified)
          .replaceAll('@REFUSE@', '$refuseResolutionMerge'),
      name: 'gh',
    );

    Future<String> mergeThroughApi(GitDir gitDir, String gh) =>
        ReleasePublisher(
          commitHeadless: true,
          repoSlug: 'owner/repo',
          ghBinary: gh,
        ).mergeRemoteBranchInto(gitDir, 'release-prep/x', 'main', logger);

    Future<String> remoteResolutionBranches() async {
      final branches = await Process.run('git', [
        'branch',
        '--list',
        'merge-resolution/*',
      ], workingDirectory: bareRemote.path);
      return (branches.stdout as String).trim();
    }

    test('through the API, resolves conflicts in this branch\'s favor and '
        'removes the temporary branch', () async {
      await setUpDivergedBranches(conflicting: true);
      final gitDir = await fixture.gitDir;
      final tree = (await gitDir.runCommand([
        'rev-parse',
        'HEAD^{tree}',
      ])).stdout.toString().trim();
      final mainSha = (await gitDir.runCommand([
        'rev-parse',
        'origin/main',
      ])).stdout.toString().trim();

      final tip = await mergeThroughApi(gitDir, fakeGitHub());

      expect(await isMergeCommit(gitDir, tip), isTrue);
      expect(await isAncestor(gitDir, 'origin/main', tip, logger), isTrue);
      expect((await gitDir.currentBranch()).branchName, 'release-prep/x');
      expect(File('${fixture.root.path}/c.txt').readAsStringSync(), 'mine');
      expect(await remoteResolutionBranches(), isEmpty);

      final calls = File('${scripts.path}/gh.log').readAsLinesSync();
      expect(calls, hasLength(4));
      expect(calls[0], contains('base=release-prep/x -f head=main'));
      expect(
        calls[1],
        allOf(contains('tree=$tree'), contains('parents[]=$mainSha')),
      );
      expect(calls[2], contains('ref=refs/heads/merge-resolution/'));
      expect(
        calls[3],
        allOf(
          contains('base=release-prep/x'),
          contains('head=merge-resolution/release-prep-x'),
        ),
      );
    });

    test('through the API, throws without creating a branch when GitHub '
        'does not sign the resolution commit', () async {
      await setUpDivergedBranches(conflicting: true);
      final gitDir = await fixture.gitDir;

      await expectLater(
        mergeThroughApi(gitDir, fakeGitHub(verified: 'false')),
        throwsA(
          isA<GitReleaseActionError>().having(
            (e) => e.message,
            'message',
            allOf(contains('did not sign'), contains('local run')),
          ),
        ),
      );

      expect(await remoteResolutionBranches(), isEmpty);
      final calls = File('${scripts.path}/gh.log').readAsLinesSync();
      expect(calls.where((call) => call.contains('git/refs')), isEmpty);
      expect(
        calls.where((call) => call.contains('head=merge-resolution')),
        isEmpty,
      );
    });

    test('through the API, removes the temporary branch and reports both '
        'errors when the resolved merge is refused', () async {
      await setUpDivergedBranches(conflicting: true);
      final gitDir = await fixture.gitDir;

      await expectLater(
        mergeThroughApi(gitDir, fakeGitHub(refuseResolutionMerge: true)),
        throwsA(
          isA<GitReleaseActionError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('even after resolving its conflicts: boom'),
              contains('First attempt: Merge conflict'),
            ),
          ),
        ),
      );
      expect(await remoteResolutionBranches(), isEmpty);
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
