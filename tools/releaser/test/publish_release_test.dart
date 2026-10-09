// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// Phase 2's decisions, run for real against a `FixtureRepo` with a fake
// `GithubCommandWrapper`. Every package is already "on pub.dev" at its
// target version here, so the tests never reach the tag-push/workflow-wait
// steps -- they cover what is checked before publishing and what happens
// after it.

import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:releaser/github_cmd_wrapper.dart';
import 'package:releaser/published_versions.dart';
import 'package:test/test.dart';
import 'package:version/version.dart';

import '../bin/publish_release.dart';
import 'support/fixture_repo.dart';

const _repoSlug = 'owner/repo';

class _FakeGithub extends GithubCommandWrapper {
  _FakeGithub(super.cwd);

  bool ciSucceeded = true;
  MergedPullRequest? pr;
  String? tagSha;

  final createdPullRequests = <({String base, String head})>[];
  final autoMerged = <int>[];
  final createdReleases = <({String tag, bool latest, bool prerelease})>[];

  @override
  Future<bool> commitStatusIsSuccess(
    Logger logger,
    String repoSlug,
    String sha,
    String context,
  ) async => ciSucceeded;

  @override
  Future<MergedPullRequest?> findMergedPullRequestForCommit(
    Logger logger,
    String repoSlug,
    String sha,
  ) async => pr;

  @override
  Future<String?> remoteTagCommitSha(
    Logger logger,
    String tagName, {
    String remote = 'origin',
  }) async => tagSha;

  @override
  Future<GHRelease?> getReleaseByTagName(
    Logger logger,
    String repoSlug,
    String tagName,
  ) async => null;

  @override
  Future<void> createRelease(
    Logger logger, {
    required String tag,
    required String title,
    required String notes,
    required bool latest,
    required bool prerelease,
  }) async =>
      createdReleases.add((tag: tag, latest: latest, prerelease: prerelease));

  @override
  Future<int?> findOpenPullRequest(
    Logger logger, {
    required String head,
    required String base,
  }) async => null;

  @override
  Future<String> createPullRequest(
    Logger logger, {
    required String base,
    required String head,
    required String title,
    required String body,
  }) async {
    createdPullRequests.add((base: base, head: head));
    return 'https://github.com/$_repoSlug/pull/7';
  }

  @override
  Future<void> enableAutoMergeWithMergeCommit(
    Logger logger,
    int prNumber,
  ) async => autoMerged.add(prNumber);
}

void main() {
  late FixtureRepo fixture;
  late _FakeGithub github;
  late GitDir fixtureGitDir;

  /// Commit A, the merge `F` that landed a release-prep branch (A then B) on
  /// `main`, and an unrelated commit.
  late String commitA;
  late String merge;
  late String unrelated;

  Future<String> git(List<String> args) async =>
      ((await (await fixture.gitDir).runCommand(args)).stdout as String).trim();

  String body({String? contentCommit, String version = '2.3.0'}) =>
      '## Versions\n\n'
      '${contentCommit == null ? '' : '_Content commit: `$contentCommit`_\n\n'}'
      '| Package | Current | New | Bump |\n'
      '|---|---|---|---|\n'
      '| datadog_dio | 2.2.0 | $version | minor |\n';

  MergedPullRequest pullRequest({
    String? body_,
    String baseRef = 'main',
    String headRef = 'release-prep/x',
    String? headRepo = _repoSlug,
    String? mergeCommitSha,
  }) => MergedPullRequest(
    number: 5,
    body: body_ ?? body(contentCommit: commitA),
    baseRef: baseRef,
    headRef: headRef,
    headRepo: headRepo,
    mergeCommitSha: mergeCommitSha ?? merge,
  );

  Future<void> publish({String? sha}) => publishRelease(
    gitDir: fixtureGitDir,
    github: github,
    repoSlug: _repoSlug,
    sha: sha ?? merge,
    runTimeout: const Duration(seconds: 1),
    publishedVersions: (name) async =>
        PublishedVersions([Version.parse('2.3.0')]),
  );

  setUp(() async {
    fixture = await FixtureRepo.create();
    fixtureGitDir = await fixture.gitDir;
    github = _FakeGithub(fixture.root.path);

    final base = await git(['rev-parse', 'HEAD']);
    await git(['checkout', '-q', '-b', 'mainline']);
    fixture.writeFile('previous-release.txt', 'x');
    await fixture.commit('chore: previous release');

    await git(['checkout', '-q', '-b', 'prep', base]);
    fixture.writeFile(
      'packages/datadog_dio/CHANGELOG.md',
      '## 2.3.0\n- A change.\n',
    );
    await fixture.commit('chore(release): update changelog and bump versions');
    commitA = await git(['rev-parse', 'HEAD']);
    await git(['commit', '-q', '--allow-empty', '-m', 'chore: publish-prep']);

    await git(['checkout', '-q', 'mainline']);
    await git(['merge', '-q', '--no-ff', '--no-edit', 'prep']);
    merge = await git(['rev-parse', 'HEAD']);
    unrelated = await git([
      'commit-tree',
      '-m',
      'unrelated',
      await git(['hash-object', '-t', 'tree', '/dev/null']),
    ]);

    // What `git fetch` would have left in a real checkout.
    await git(['update-ref', 'refs/remotes/origin/main', merge]);
    await git(['update-ref', 'refs/remotes/origin/develop', base]);
    await git(['update-ref', 'refs/remotes/origin/release-content/x', commitA]);
    await git([
      'update-ref',
      'refs/remotes/origin/release/datadog_dio/v2.3.x',
      merge,
    ]);

    github.pr = pullRequest();
    github.tagSha = merge;
  });

  tearDown(() => fixture.delete());

  group('a commit that is not a release', () {
    test('without a merged PR is skipped', () async {
      github.pr = null;

      await publish();

      expect(github.createdReleases, isEmpty);
      expect(github.createdPullRequests, isEmpty);
    });

    test('whose PR was not opened from release-prep/* is skipped', () async {
      github.pr = pullRequest(headRef: 'feature/something');

      await publish();

      expect(github.createdReleases, isEmpty);
    });
  });

  group('refuses', () {
    test('when the CI status is not success', () async {
      github.ciSucceeded = false;

      await expectLater(publish(), throwsStateError);
    });

    test('a PR that did not merge as this commit', () async {
      github.pr = pullRequest(mergeCommitSha: unrelated);

      await expectLater(
        publish(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('did not merge as'),
          ),
        ),
      );
    });

    test('a PR opened from a fork', () async {
      github.pr = pullRequest(headRepo: 'someone/fork');

      await expectLater(
        publish(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('someone/fork'),
          ),
        ),
      );
    });

    test('a commit that is not a merge commit', () async {
      github.pr = pullRequest(mergeCommitSha: commitA);

      await expectLater(
        publish(sha: commitA),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('not a merge commit'),
          ),
        ),
      );
    });

    test('a version the pubspec at this commit does not have', () async {
      github.pr = pullRequest(
        body_: body(contentCommit: commitA, version: '2.9.9'),
      );

      await expectLater(
        publish(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('pubspec.yaml'),
          ),
        ),
      );
    });

    test(
      'a content commit that is not part of this commit\'s history',
      () async {
        github.pr = pullRequest(body_: body(contentCommit: unrelated));

        await expectLater(
          publish(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('not part of'),
            ),
          ),
        );
      },
    );

    test(
      'a PR body with no content commit outside a support release',
      () async {
        github.pr = pullRequest(body_: body());

        await expectLater(publish(), throwsStateError);
      },
    );

    test('a commit that is not on the PR\'s base branch', () async {
      await git(['update-ref', 'refs/remotes/origin/main', commitA]);

      await expectLater(publish(), throwsStateError);
    });
  });

  group('publishes', () {
    test('a mainline release and opens the backport PR from the content '
        'branch', () async {
      await publish();

      expect(github.createdReleases, hasLength(1));
      expect(github.createdReleases.single.tag, 'datadog_dio/v2.3.0');
      expect(github.createdReleases.single.latest, isFalse);
      expect(github.createdPullRequests, [
        (base: 'develop', head: 'release-content/x'),
      ]);
      expect(github.autoMerged, [7]);
    });

    test('a support release without a backport', () async {
      github.pr = pullRequest(
        body_: body(),
        baseRef: 'release/datadog_dio/v2.3.x',
      );

      await publish();

      expect(github.createdReleases, hasLength(1));
      expect(github.createdReleases.single.latest, isFalse);
      expect(github.createdPullRequests, isEmpty);
      expect(github.autoMerged, isEmpty);
    });
  });
}
