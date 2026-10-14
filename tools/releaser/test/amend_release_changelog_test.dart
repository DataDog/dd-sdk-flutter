// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:releaser/git/release_git.dart';
import 'package:releaser/github_cmd_wrapper.dart';
import 'package:test/test.dart';

import '../bin/amend_release_changelog.dart';
import 'support/fixture_repo.dart';
import 'support/test_temp.dart';

/// Stubs the two `gh`-calling methods `amendReleaseChangelog` uses, and
/// records how [editPullRequestBody] was called so tests can assert on the
/// rewritten body without a real PR to edit.
class _FakeGithub extends GithubCommandWrapper {
  _FakeGithub(super.cwd, this._pr);

  final OpenPullRequest? _pr;
  int? editedNumber;
  String? editedBody;

  @override
  Future<OpenPullRequest?> findOpenPullRequestByHead(
    Logger logger,
    String head,
  ) async => _pr;

  @override
  Future<void> editPullRequestBody(
    Logger logger,
    int number,
    String body,
  ) async {
    editedNumber = number;
    editedBody = body;
  }
}

/// A release PR body shaped like `release_pr.dart`'s real output -- just
/// enough for `amend_release_changelog.dart` to parse a content commit and
/// a versions table out of, plus a CHANGELOG.md link so the successful-run
/// test can assert on rewriting more than just the one labeled line.
String _prBody(
  String contentCommit, {
  List<String> packages = const ['datadog_dio'],
}) {
  final buffer = StringBuffer()
    ..writeln('## Versions')
    ..writeln()
    ..writeln('_Content commit: `$contentCommit`_')
    ..writeln()
    ..writeln('| Package | Current | New | Bump |')
    ..writeln('|---|---|---|---|');
  for (final package in packages) {
    buffer.writeln('| $package | 2.3.0 | 2.4.0 | minor |');
  }
  buffer
    ..writeln()
    ..writeln(
      'See [CHANGELOG.md](https://github.com/x/y/blob/$contentCommit/'
      'packages/datadog_dio/CHANGELOG.md) for changes.',
    );
  return buffer.toString();
}

void main() {
  late FixtureRepo fixture;
  late Directory bareRemote;
  late String commitA;
  late String commitB;
  const workingBranch = 'release-prep/20260925-abc123';
  const contentBranchName = 'release-content/20260925-abc123';
  final logger = Logger('amend_release_changelog_test');

  setUp(() async {
    fixture = await FixtureRepo.create();
    await fixture.checkoutNewBranch(workingBranch);
    final gitDir = await fixture.gitDir;

    fixture.writeFile(
      'packages/datadog_dio/CHANGELOG.md',
      '## 2.4.0\n- Original entry.\n',
    );
    await fixture.commit('chore(release): update changelog and bump versions');
    commitA = (await gitDir.runCommand([
      'rev-parse',
      'HEAD',
    ])).stdout.toString().trim();

    await fixture.commit('chore(release): publish-prep');
    commitB = (await gitDir.runCommand([
      'rev-parse',
      'HEAD',
    ])).stdout.toString().trim();

    bareRemote = await createTestTempDir(
      'amend_release_changelog_test_remote_',
    );
    await Process.run('git', ['init', '-q', '--bare', bareRemote.path]);
    await Process.run('git', [
      'remote',
      'add',
      'origin',
      bareRemote.path,
    ], workingDirectory: fixture.root.path);
    await pushBranch(gitDir, workingBranch, logger);
    await pushBranchAt(gitDir, contentBranchName, commitA, logger);
  });

  tearDown(() async {
    await fixture.delete();
    await bareRemote.delete(recursive: true);
  });

  test('folds a hand-edited CHANGELOG.md into commit A, replays commit B, '
      'force-pushes both branches, and rewrites the PR body', () async {
    final gitDir = await fixture.gitDir;
    fixture.writeFile(
      'packages/datadog_dio/CHANGELOG.md',
      '## 2.4.0\n- Fixed entry.\n',
    );
    final github = _FakeGithub(
      fixture.root.path,
      OpenPullRequest(number: 42, body: _prBody(commitA)),
    );

    await amendReleaseChangelog(gitDir: gitDir, github: github);

    // Still exactly two commits on the working branch.
    final root = (await gitDir.runCommand([
      'rev-list',
      '--max-parents=0',
      'HEAD',
    ])).stdout.toString().trim();
    expect(await commitCountBetween(gitDir, root, 'HEAD', logger), 2);

    final newHead = (await gitDir.runCommand([
      'rev-parse',
      'HEAD',
    ])).stdout.toString().trim();
    final newContentCommit = (await gitDir.runCommand([
      'rev-parse',
      'HEAD~1',
    ])).stdout.toString().trim();
    expect(newHead, isNot(commitB));
    expect(newContentCommit, isNot(commitA));

    final changelog = File(
      p.join(fixture.root.path, 'packages/datadog_dio/CHANGELOG.md'),
    );
    expect(changelog.readAsStringSync(), contains('Fixed entry'));

    final remoteContentSha = await Process.run('git', [
      'rev-parse',
      '$contentBranchName^{commit}',
    ], workingDirectory: bareRemote.path);
    expect((remoteContentSha.stdout as String).trim(), newContentCommit);

    final remoteWorkingSha = await Process.run('git', [
      'rev-parse',
      '$workingBranch^{commit}',
    ], workingDirectory: bareRemote.path);
    expect((remoteWorkingSha.stdout as String).trim(), newHead);

    expect(github.editedNumber, 42);
    expect(github.editedBody, isNot(contains(commitA)));
    // Both occurrences of the old SHA were rewritten: the "Content commit"
    // line and the CHANGELOG.md link.
    expect(
      RegExp(
        RegExp.escape(newContentCommit),
      ).allMatches(github.editedBody!).length,
      2,
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('refuses when the hand-edit touches a commit-B-only file', () async {
    final gitDir = await fixture.gitDir;
    fixture.writeFile(
      'packages/datadog_dio/CHANGELOG.md',
      '## 2.4.0\n- Fixed entry.\n',
    );
    // Any non-CHANGELOG.md file is ineligible, but pubspec_overrides.yaml
    // specifically is also never part of commit A at all -- it's a
    // melos-bootstrap artifact. A purely local check, so a real (unstubbed)
    // GithubCommandWrapper never actually gets called.
    fixture.writeFile(
      'packages/datadog_dio/pubspec_overrides.yaml',
      'dependency_overrides:\n  datadog_common_test:\n    path: ../datadog_common_test\n',
    );

    await expectLater(
      amendReleaseChangelog(
        gitDir: gitDir,
        github: GithubCommandWrapper(fixture.root.path),
      ),
      throwsStateError,
    );

    // Refused before touching anything -- HEAD is untouched.
    final gitDirAfter = await fixture.gitDir;
    final head = (await gitDirAfter.runCommand([
      'rev-parse',
      'HEAD',
    ])).stdout.toString().trim();
    expect(head, commitB);
  });

  test('refuses a pubspec.yaml edit even inside a real workspace package -- '
      'this tool is changelog-only', () async {
    final gitDir = await fixture.gitDir;
    fixture.writeFile(
      'packages/datadog_dio/pubspec.yaml',
      'name: datadog_dio\nversion: 2.4.1\n',
    );

    await expectLater(
      amendReleaseChangelog(
        gitDir: gitDir,
        github: GithubCommandWrapper(fixture.root.path),
      ),
      throwsStateError,
    );
  });

  test('refuses a CHANGELOG.md edit to a real workspace package that is not '
      'part of this release', () async {
    final gitDir = await fixture.gitDir;
    fixture.writeFile(
      'packages/datadog_flutter_plugin/CHANGELOG.md',
      '## 2.4.0\n- Sneaked in.\n',
    );
    // Passes the local-only "is this a real package's CHANGELOG.md" check;
    // the package-is-releasing check (against `_prBody`'s default,
    // datadog_dio-only table) needs the PR, so it can't be a real
    // GithubCommandWrapper.
    final github = _FakeGithub(
      fixture.root.path,
      OpenPullRequest(number: 42, body: _prBody(commitA)),
    );

    await expectLater(
      amendReleaseChangelog(gitDir: gitDir, github: github),
      throwsStateError,
    );

    final head = (await gitDir.runCommand([
      'rev-parse',
      'HEAD',
    ])).stdout.toString().trim();
    expect(head, commitB);
  });

  test('refuses a same-named CHANGELOG.md outside any workspace package '
      "(basename alone isn't enough)", () async {
    final gitDir = await fixture.gitDir;
    fixture.writeFile('tools/releaser/CHANGELOG.md', '## 9.9.9\n');

    await expectLater(
      amendReleaseChangelog(
        gitDir: gitDir,
        github: GithubCommandWrapper(fixture.root.path),
      ),
      throwsStateError,
    );
  });

  test('refuses when the remote release-prep branch moved since this '
      'checkout was made', () async {
    final gitDir = await fixture.gitDir;
    fixture.writeFile(
      'packages/datadog_dio/CHANGELOG.md',
      '## 2.4.0\n- Fixed entry.\n',
    );
    // Reaches the PR fetch, so it needs a working stub rather than a real
    // GithubCommandWrapper.
    final github = _FakeGithub(
      fixture.root.path,
      OpenPullRequest(number: 42, body: _prBody(commitA)),
    );

    // Simulate another actor pushing to workingBranch on the remote,
    // without touching this checkout.
    final otherClone = await createTestTempDir(
      'amend_release_changelog_test_other_clone_',
    );
    await Process.run('git', [
      'clone',
      '-q',
      '-b',
      workingBranch,
      bareRemote.path,
      otherClone.path,
    ]);
    await Process.run('git', [
      'commit',
      '--allow-empty',
      '-m',
      'chore: someone else pushed this',
    ], workingDirectory: otherClone.path);
    await Process.run('git', [
      'push',
      'origin',
      workingBranch,
    ], workingDirectory: otherClone.path);

    try {
      await expectLater(
        amendReleaseChangelog(gitDir: gitDir, github: github),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('someone else pushed'),
          ),
        ),
      );

      final head = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();
      expect(head, commitB);
    } finally {
      await otherClone.delete(recursive: true);
    }
  });

  test('refuses when the remote release-content branch was already moved '
      'by another amend run', () async {
    final gitDir = await fixture.gitDir;
    fixture.writeFile(
      'packages/datadog_dio/CHANGELOG.md',
      '## 2.4.0\n- Fixed entry.\n',
    );
    final github = _FakeGithub(
      fixture.root.path,
      OpenPullRequest(number: 42, body: _prBody(commitA)),
    );

    // Simulate a concurrent amend run that already moved the content
    // branch, without touching this checkout or its PR.
    final otherClone = await createTestTempDir(
      'amend_release_changelog_test_other_clone_',
    );
    await Process.run('git', [
      'clone',
      '-q',
      '-b',
      contentBranchName,
      bareRemote.path,
      otherClone.path,
    ]);
    await Process.run('git', [
      'commit',
      '--allow-empty',
      '-m',
      'chore: a concurrent amend run',
    ], workingDirectory: otherClone.path);
    await Process.run('git', [
      'push',
      'origin',
      contentBranchName,
    ], workingDirectory: otherClone.path);

    try {
      await expectLater(
        amendReleaseChangelog(gitDir: gitDir, github: github),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('another amend run already moved it'),
          ),
        ),
      );

      final head = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();
      expect(head, commitB);
    } finally {
      await otherClone.delete(recursive: true);
    }
  });

  test('refuses with no working tree changes at all', () async {
    final gitDir = await fixture.gitDir;

    await expectLater(
      amendReleaseChangelog(
        gitDir: gitDir,
        github: GithubCommandWrapper(fixture.root.path),
      ),
      throwsStateError,
    );
  });

  test(
    'refuses before touching anything when no open PR exists for the branch',
    () async {
      final gitDir = await fixture.gitDir;
      fixture.writeFile(
        'packages/datadog_dio/CHANGELOG.md',
        '## 2.4.0\n- Fixed entry.\n',
      );
      final github = _FakeGithub(fixture.root.path, null);

      await expectLater(
        amendReleaseChangelog(gitDir: gitDir, github: github),
        throwsStateError,
      );

      final head = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();
      expect(head, commitB);
    },
  );

  test('refuses before touching anything when the PR body has no "Content '
      'commit" line', () async {
    final gitDir = await fixture.gitDir;
    fixture.writeFile(
      'packages/datadog_dio/CHANGELOG.md',
      '## 2.4.0\n- Fixed entry.\n',
    );
    final github = _FakeGithub(
      fixture.root.path,
      OpenPullRequest(number: 7, body: 'unrelated body'),
    );

    await expectLater(
      amendReleaseChangelog(gitDir: gitDir, github: github),
      throwsStateError,
    );

    expect(github.editedBody, isNull);
    final head = (await gitDir.runCommand([
      'rev-parse',
      'HEAD',
    ])).stdout.toString().trim();
    expect(head, commitB);
  });

  test('refuses when HEAD is more than one commit past commit A', () async {
    final gitDir = await fixture.gitDir;
    await fixture.commit('chore: an unexpected extra commit');
    final github = _FakeGithub(
      fixture.root.path,
      OpenPullRequest(number: 42, body: _prBody(commitA)),
    );
    fixture.writeFile(
      'packages/datadog_dio/CHANGELOG.md',
      '## 2.4.0\n- Fixed entry.\n',
    );

    await expectLater(
      amendReleaseChangelog(gitDir: gitDir, github: github),
      throwsStateError,
    );
  });

  test('refuses a patch release with no content commit to amend, without '
      "mistaking it for 'not a release-prep branch'", () async {
    final patchFixture = await FixtureRepo.create();
    const patchBranch = 'release/datadog_dio/v2.3.x';
    await patchFixture.checkoutNewBranch(patchBranch);
    patchFixture.writeFile(
      'packages/datadog_dio/CHANGELOG.md',
      '## 2.3.1\n- A patch entry.\n',
    );
    await patchFixture.commit('chore(release): prepare support release');
    final patchGitDir = await patchFixture.gitDir;

    try {
      // Purely a branch-name check, so a real (unstubbed)
      // GithubCommandWrapper never actually gets called.
      await expectLater(
        amendReleaseChangelog(
          gitDir: patchGitDir,
          github: GithubCommandWrapper(patchFixture.root.path),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('support-branch releases never split'),
          ),
        ),
      );
    } finally {
      await patchFixture.delete();
    }
  });
}
