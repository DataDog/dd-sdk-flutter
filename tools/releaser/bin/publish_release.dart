// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// `publish-release.yml`'s entry point -- Phase 2's orchestrator. Triggered
// by a `release-trigger/*` tag, pushed by a GitLab job only once its own
// pipeline has actually succeeded for that commit.
//
// Runs against a checkout of the tagged commit and does, in order:
//   1. Verifies GitHub's own `dd-gitlab/notify-pipeline-succeeded` status is
//      `success` for this exact commit -- tags aren't branch-protected, so
//      this alone doesn't prove the commit came from a legitimate release
//      branch (that status is posted for any branch's pipeline).
//   2. Reconstructs what `prepare_release.dart` did from the release PR that
//      merged this commit (found via GitHub's commit-to-PR association, so
//      it works regardless of merge strategy), and exits quietly if there is
//      none, or it wasn't opened from `release-prep/*` -- every push to a
//      release branch fires the trigger, and most aren't releases. The PR
//      must have merged as exactly this commit, be a merge commit, come from
//      this repository, name versions that match the pubspecs at this commit,
//      and (outside a support release) name a content commit that is part of
//      this commit's history. The branch is the PR's own base ref, GitHub's
//      record of what it merged into; this commit is then required to be
//      reachable from it, closing the gap step 1 alone leaves open.
//   3. For each package, in that (already topological) order:
//      skip if pub.dev already has that version (idempotent re-run); else
//      push that package's `<package>/v<version>` tag (this repo's
//      pre-existing tag convention) and wait for the dedicated
//      `publish-package.yml` run it triggers to succeed -- pub.dev's OIDC
//      trusted publishing only accepts a run triggered by that exact
//      package's own tag, so one shared workflow run can't just call
//      `dart pub publish` for each package in turn -- then create its
//      GitHub Release with notes pulled from its `CHANGELOG.md`.
//   4. Backports commit A into the dev-line branch (`develop`/`v4`) via a
//      reviewed, auto-merge on approval PR from the `release-content/*` branch
//
// Any failure aborts loudly and exits non-zero; `publish-release.yml`'s own
// `if: failure()` step (using slackapi/slack-github-action, the pattern
// already established elsewhere in the DataDog org) is what alerts
// `#dd-sdk-flutter` -- this tool doesn't post to Slack itself.

import 'dart:io';

import 'package:args/args.dart';
import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:releaser/changelog_util.dart';
import 'package:releaser/cli_logging.dart';
import 'package:releaser/git/git_dir.dart';
import 'package:releaser/git/release_git.dart';
import 'package:releaser/github_cmd_wrapper.dart';
import 'package:releaser/manifest.dart';
import 'package:releaser/publish_rules.dart';
import 'package:releaser/published_versions.dart';
import 'package:version/version.dart';

final _log = Logger('publish_release');

const _ciStatusContext = 'dd-gitlab/notify-pipeline-succeeded';
const _publishWorkflowFile = 'publish-package.yml';

Future<void> main(List<String> arguments) async {
  configureCliLogging();

  final argParser = ArgParser()
    ..addOption(
      'repo-root',
      help: 'Repo root to run against. Defaults to the current directory.',
    )
    ..addOption(
      'run-timeout-minutes',
      // No manual approval gates a package's publish right now (see
      // publish-package.yml), so this only needs to cover real pub.dev/
      // GitHub Actions latency, not human response time.
      defaultsTo: '30',
      help:
          "Max time to wait for each package's publish-package.yml run to "
          'finish before giving up on it.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults args;
  try {
    args = argParser.parse(arguments);
  } on FormatException catch (e) {
    _log.shout('❌ ${e.message}\n\n${argParser.usage}');
    exitCode = 1;
    return;
  }

  if (args['help'] as bool) {
    print(argParser.usage);
    return;
  }

  final gitDir = await getGitDir(args['repo-root'] as String?);
  if (gitDir == null) {
    exitCode = 1;
    return;
  }

  final github = GithubCommandWrapper(gitDir.path);
  final repoSlug = await github.repoSlug(_log);
  final sha = (await Process.run('git', [
    'rev-parse',
    'HEAD',
  ], workingDirectory: gitDir.path)).stdout.toString().trim();
  final runTimeout = Duration(
    minutes: int.parse(args['run-timeout-minutes'] as String),
  );

  try {
    await publishRelease(
      gitDir: gitDir,
      github: github,
      repoSlug: repoSlug,
      sha: sha,
      runTimeout: runTimeout,
    );
  } catch (e) {
    final message = e is StateError ? e.message : '$e';
    _log.shout('❌ $message');
    exitCode = 1;
  }
}

Future<void> publishRelease({
  required GitDir gitDir,
  required GithubCommandWrapper github,
  required String repoSlug,
  required String sha,
  required Duration runTimeout,
  PublishedVersionsGateway publishedVersions = fetchPublishedVersions,
}) async {
  final ciOk = await github.commitStatusIsSuccess(
    _log,
    repoSlug,
    sha,
    _ciStatusContext,
  );
  if (!ciOk) {
    throw StateError(
      '$sha has no successful $_ciStatusContext status -- refusing to '
      'publish. This should only happen if a release-trigger/* tag was '
      'pushed by hand rather than by the GitLab job that pushes it once '
      'its own pipeline actually succeeds.',
    );
  }

  final pr = await github.findMergedPullRequestForCommit(_log, repoSlug, sha);
  if (pr == null || !pr.headRef.startsWith('release-prep/')) {
    // Every push to a release branch fires the trigger, including ones that
    // aren't a release (a cherry-picked fix on a support branch, for one).
    _log.info('ℹ️ $sha is not a release-prep merge -- nothing to publish.');
    return;
  }
  // The lookup also returns PRs that merely contain `sha`, and a PR from a
  // fork can reuse a `release-prep/*` branch name -- neither is a release.
  if (pr.mergeCommitSha != sha) {
    throw StateError(
      'PR #${pr.number} did not merge as $sha (its merge commit is '
      '${pr.mergeCommitSha}) -- refusing to publish.',
    );
  }
  if (pr.headRepo != repoSlug) {
    throw StateError(
      'PR #${pr.number} was opened from ${pr.headRepo ?? 'a deleted fork'}, '
      'not $repoSlug -- refusing to publish.',
    );
  }
  if (!await isMergeCommit(gitDir, sha)) {
    throw StateError(
      '$sha is not a merge commit -- refusing to publish. Release-prep PRs '
      'must be merged with "Create a merge commit": a squash or rebase '
      'leaves the next release\'s commit range unable to tell what this '
      'one already shipped.',
    );
  }
  final (manifest, sourceBranch) = await _manifestFromReleasePr(
    gitDir,
    pr,
    sha,
  );

  if (manifest.packages.isEmpty) {
    throw StateError('$sha has nothing to publish.');
  }
  _log.info('ℹ️ Publishing ${manifest.packages.length} package(s) from $sha.');

  for (final entry in manifest.packages) {
    await _publishPackage(
      entry,
      gitDir: gitDir,
      github: github,
      repoSlug: repoSlug,
      sha: sha,
      runTimeout: runTimeout,
      publishedVersions: publishedVersions,
    );
  }

  final contentCommit = manifest.contentCommit;
  if (contentCommit == null || sourceBranch == null) {
    _log.info('ℹ️ No content commit to backport (support release).');
    return;
  }

  await _backportContentCommit(
    contentCommit,
    sourceBranch,
    gitDir: gitDir,
    github: github,
    repoSlug: repoSlug,
  );

  _log.info('✅ Release publish complete for $sha.');
}

/// Reconstructs a run's manifest from [pr]'s body. Also returns the branch
/// commit A is backported into: the source branch [pr]'s base ref maps to,
/// or `null` for a support release, which has no commit A. [pr]'s base ref
/// itself must contain [sha] (see [_checkOnBranch]).
Future<(ReleaseManifest, String?)> _manifestFromReleasePr(
  GitDir gitDir,
  MergedPullRequest pr,
  String sha,
) async {
  final sourceBranch = sourceBranchFor(pr.baseRef);
  await _checkOnBranch(gitDir, sha, pr.baseRef);

  final isSupport = isSupportBranch(pr.baseRef);
  final contentCommit = parseContentCommit(pr.body);
  if (!isSupport && contentCommit == null) {
    throw StateError(
      'PR #${pr.number}\'s body has no "Content commit" line -- not a '
      'release-prep PR?',
    );
  }

  final packages = await manifestPackagesFor(
    parseVersionsTable(pr.body),
    repoRoot: gitDir.path,
    isSupport: isSupport,
  );
  _checkPubspecVersions(gitDir, packages);
  if (!isSupport && !await isAncestor(gitDir, contentCommit!, sha, _log)) {
    throw StateError(
      'The content commit $contentCommit named in PR #${pr.number}\'s body is '
      'not part of $sha\'s history -- refusing to publish.',
    );
  }
  return (
    ReleaseManifest(
      contentCommit: isSupport ? null : contentCommit,
      packages: packages,
    ),
    isSupport ? null : sourceBranch,
  );
}

/// The PR body is editable by anyone with write access, so the versions it
/// names are only trusted once they match what the merged tree actually
/// contains.
void _checkPubspecVersions(GitDir gitDir, List<ManifestPackageEntry> packages) {
  for (final entry in packages) {
    final pubspec = File(
      p.join(gitDir.path, entry.relativePath, 'pubspec.yaml'),
    );
    final declared = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync())?.group(1);
    if (declared != entry.toVersion) {
      throw StateError(
        'The release PR says ${entry.package} ${entry.toVersion}, but its '
        'pubspec.yaml at this commit says ${declared ?? 'no version'} -- '
        'refusing to publish.',
      );
    }
  }
}

/// A green CI status alone doesn't prove [sha] came from a legitimate
/// release branch -- that status is posted for *any* branch's pipeline, so
/// someone with push access could otherwise get a feature branch green and
/// hand-push a release-trigger/* tag at it. Requires [sha] to actually be
/// reachable from [branch], which the caller derived from a source outside
/// the tag itself (a merged PR's base ref, or the triggering commit's own
/// message).
Future<void> _checkOnBranch(GitDir gitDir, String sha, String branch) async {
  final onBranch = await isAncestor(gitDir, sha, 'origin/$branch', _log);
  if (!onBranch) {
    throw StateError(
      '$sha is not reachable from origin/$branch -- refusing to publish. '
      'A successful CI status alone does not prove this commit came from a '
      'legitimate release branch.',
    );
  }
}

/// Publishes [entry] and creates its GitHub Release. The two halves --
/// "is it on pub.dev" and "does its GitHub Release exist" -- are checked
/// and made to hold independently, not gated behind one shared skip: a
/// prior run could have published successfully but died before (or during)
/// `gh release create`, and a re-run has to still create that release
/// rather than treating "already on pub.dev" as "nothing left to do here".
Future<void> _publishPackage(
  ManifestPackageEntry entry, {
  required GitDir gitDir,
  required GithubCommandWrapper github,
  required String repoSlug,
  required String sha,
  required Duration runTimeout,
  required PublishedVersionsGateway publishedVersions,
}) async {
  final targetVersion = Version.parse(entry.toVersion);
  final tagName = '${entry.package}/v${entry.toVersion}';

  final published = await publishedVersions(entry.package);
  if (published.versions.contains(targetVersion)) {
    // No push -- just confirm the tag points at `sha`. `--verify-tag` below
    // only checks it exists, not where it points.
    final existingSha = await github.remoteTagCommitSha(_log, tagName);
    if (existingSha != sha) {
      throw StateError(
        '${entry.package} $targetVersion is already on pub.dev, but '
        '$tagName points at $existingSha, not $sha -- refusing to create a '
        'release against the wrong commit.',
      );
    }
    _log.info(
      'ℹ️ ${entry.package} $targetVersion is already on pub.dev -- '
      'skipping tag-push/publish (idempotent re-run).',
    );
  } else {
    await _ensureTagPushed(github, gitDir, tagName, sha);

    final run = await _waitForWorkflowRun(
      github,
      repoSlug,
      _publishWorkflowFile,
      tagName,
      timeout: runTimeout,
    );
    if (run == null) {
      throw StateError(
        'No $_publishWorkflowFile run was found for $tagName within '
        '${runTimeout.inMinutes} minute(s).',
      );
    }
    if (!run.succeeded) {
      throw StateError(
        '$_publishWorkflowFile run for $tagName did not succeed '
        '(status: ${run.status}, conclusion: ${run.conclusion}) -- '
        '${run.url}',
      );
    }
  }

  if (await github.getReleaseByTagName(_log, repoSlug, tagName) != null) {
    _log.info(
      'ℹ️ GitHub Release $tagName already exists -- skipping '
      '(idempotent re-run).',
    );
    return;
  }

  final changelogFile = File(
    p.join(gitDir.path, entry.relativePath, 'CHANGELOG.md'),
  );
  final notes =
      extractChangelogSection(changelogFile, entry.toVersion) ??
      'See CHANGELOG.md.';

  await github.createRelease(
    _log,
    tag: tagName,
    title: '${entry.package} ${entry.toVersion}',
    notes: notes,
    latest: shouldMarkReleaseLatest(
      package: entry.package,
      prerelease: entry.prerelease,
      isSupport: entry.isSupport,
    ),
    prerelease: entry.prerelease,
  );
  _log.info('✅ Published and released ${entry.package} $targetVersion.');
}

/// Pushes [tagName] at [sha], tolerating a re-run after a partial failure:
/// if the tag already exists remotely and already points at [sha], this is
/// a no-op rather than the "tag already exists" error a plain `git push`
/// would give -- that error would otherwise turn every retry after a
/// publish failure into a manual tag-deletion incident. A tag that exists
/// but points somewhere *else* is a real conflict and still throws.
Future<void> _ensureTagPushed(
  GithubCommandWrapper github,
  GitDir gitDir,
  String tagName,
  String sha,
) async {
  final existingSha = await github.remoteTagCommitSha(_log, tagName);
  if (existingSha == null) {
    _log.info('ℹ️ Publishing via $tagName.');
    await pushTag(gitDir, tagName, sha, _log);
    return;
  }
  if (existingSha == sha) {
    _log.info('ℹ️ $tagName already points at $sha -- skipping push.');
    return;
  }
  throw StateError(
    '$tagName already exists and points at $existingSha, not $sha -- '
    'refusing to overwrite it.',
  );
}

/// Polls `gh run list` for [tagRef]'s [workflow] run until it reaches a
/// terminal state or [timeout] elapses. This is what preserves topological
/// order across packages in a federated group.
Future<WorkflowRunState?> _waitForWorkflowRun(
  GithubCommandWrapper github,
  String repoSlug,
  String workflow,
  String tagRef, {
  required Duration timeout,
  Duration pollInterval = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final run = await github.latestWorkflowRun(
      _log,
      repoSlug,
      workflow,
      tagRef,
    );
    if (run != null && run.isComplete) {
      return run;
    }
    if (run == null) {
      _log.info('ℹ️ Waiting for $workflow to start for $tagRef...');
    } else {
      _log.info('ℹ️ Waiting for $workflow ($tagRef) -- status: ${run.status}');
    }
    await Future<void>.delayed(pollInterval);
  }
  return null;
}

Future<void> _backportContentCommit(
  String contentCommit,
  String devLineBranch, {
  required GitDir gitDir,
  required GithubCommandWrapper github,
  required String repoSlug,
}) async {
  final alreadyBackported = await isAncestor(
    gitDir,
    contentCommit,
    'origin/$devLineBranch',
    _log,
  );
  if (alreadyBackported) {
    _log.info(
      'ℹ️ $contentCommit is already on $devLineBranch -- skipping backport '
      '(idempotent re-run).',
    );
    return;
  }

  // `prepare_release.dart` names this branch `release-content/{id}`, at
  // commit A's SHA -- find it via the commit's own reachable refs rather
  // than reconstructing `{id}`, since that's an implementation detail of
  // `prepare_release.dart` this tool shouldn't need to know.
  final branchName = await _findContentBranch(gitDir, contentCommit);
  if (branchName == null) {
    throw StateError(
      'Could not find the release-content/* branch pointing at '
      '$contentCommit -- prepare_release.dart should have pushed one.',
    );
  }

  // A re-run after a partial failure (PR already opened, something later
  // failed before this function returned) would otherwise hit `gh pr
  // create`'s "a pull request already exists" error -- the ancestry check
  // above only catches the *merged* case, not "open but not yet merged".
  final existingPrNumber = await github.findOpenPullRequest(
    _log,
    head: branchName,
    base: devLineBranch,
  );
  final prNumber =
      existingPrNumber ??
      _prNumberFromUrl(
        await github.createPullRequest(
          _log,
          base: devLineBranch,
          head: branchName,
          title: 'chore(release): backport release content to $devLineBranch',
          body:
              'Backports the content commit ($contentCommit) from this '
              'release into `$devLineBranch`.\n\n'
              'This PR auto-merges (using a merge commit, not squash/rebase) '
              'once approved and required checks pass -- that preserves the '
              'original commit SHA on `$devLineBranch`.',
        ),
      );
  await github.enableAutoMergeWithMergeCommit(_log, prNumber);
  _log.info(
    existingPrNumber != null
        ? '✅ Backport PR #$existingPrNumber already open -- ensured '
              'auto-merge (merge commit) is enabled.'
        : '✅ Opened backport PR #$prNumber and enabled auto-merge (merge '
              'commit).',
  );
}

Future<String?> _findContentBranch(GitDir gitDir, String commitSha) async {
  final result = await Process.run('git', [
    'for-each-ref',
    '--points-at',
    commitSha,
    '--format',
    '%(refname:short)',
    'refs/remotes/origin/release-content/*',
  ], workingDirectory: gitDir.path);
  if (result.exitCode != 0) return null;

  final refs = (result.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (refs.isEmpty) return null;

  // Strip the `origin/` remote prefix `for-each-ref` includes.
  return refs.first.replaceFirst('origin/', '');
}

int _prNumberFromUrl(String prUrl) => int.parse(prUrl.trim().split('/').last);
