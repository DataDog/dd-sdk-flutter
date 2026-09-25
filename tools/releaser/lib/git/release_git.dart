// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Plain git operations `prepare_release.dart` needs for the commit-A/
/// commit-B split and its branch/push -- kept as free functions against a
/// real [GitDir] (rather than an injectable interface) since, unlike
/// `github_cmd_wrapper.dart`'s network calls, these are cheap and safe to
/// run for real against a throwaway git repo in tests (see
/// `test/support/fixture_repo.dart`); only [pushBranch] needs a real
/// remote, so tests exercise everything up to it and stop there.
///
/// Every operation throws [GitReleaseActionError] on a non-zero exit
/// rather than returning a bool, so a caller can't accidentally continue
/// past a failed branch/commit/push the way the legacy `Command.run() ->
/// bool` pattern allowed.
class GitReleaseActionError implements Exception {
  final String message;
  GitReleaseActionError(this.message);

  @override
  String toString() => message;
}

Future<ProcessResult> _run(
  GitDir gitDir,
  List<String> args,
  Logger logger,
  String failureContext,
) async {
  final result = await gitDir.runCommand(args);
  if (result.exitCode != 0) {
    logger.shout('❌ $failureContext: ${result.stderr}');
    throw GitReleaseActionError('$failureContext: ${result.stderr}');
  }
  return result;
}

/// Whether [gitDir]'s working tree has no staged or unstaged changes and no
/// untracked files -- checked before `prepareRelease` starts mutating
/// anything, since [commitAll] stages everything under [gitDir] with
/// `git add .` and would otherwise sweep up unrelated local work into a
/// release commit.
Future<bool> isWorkingTreeClean(GitDir gitDir, Logger logger) async {
  final result = await _run(
    gitDir,
    ['status', '--porcelain'],
    logger,
    'Failed to check working tree status',
  );
  return (result.stdout as String).trim().isEmpty;
}

Future<void> createAndCheckoutBranch(
  GitDir gitDir,
  String branchName,
  Logger logger,
) async {
  logger.info('ℹ️ Creating branch $branchName');
  await _run(
    gitDir,
    ['checkout', '-b', branchName],
    logger,
    'Failed to create branch $branchName',
  );
}

/// Stages everything under [gitDir] and commits, returning the new
/// commit's full SHA -- callers need this both to record
/// [ReleaseManifest.contentCommit] and, in tests, to assert the two-commit
/// split landed correctly.
Future<String> commitAll(
  GitDir gitDir,
  String message,
  Logger logger, {
  String? body,
}) async {
  await _run(gitDir, ['add', '.'], logger, 'Failed to stage changes');

  if (body != null) {
    final tempFile = File(
      p.join(
        Directory.systemTemp.path,
        'dart_releaser_commit_${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    await tempFile.writeAsString('$message\n\n$body');
    try {
      await _run(
        gitDir,
        ['commit', '-F', tempFile.path],
        logger,
        'Failed to commit',
      );
    } finally {
      await tempFile.delete();
    }
  } else {
    await _run(gitDir, ['commit', '-m', message], logger, 'Failed to commit');
  }

  final result = await _run(
    gitDir,
    ['rev-parse', 'HEAD'],
    logger,
    'Failed to resolve HEAD after commit',
  );
  return (result.stdout as String).trim();
}

Future<void> pushBranch(
  GitDir gitDir,
  String branchName,
  Logger logger, {
  String remote = 'origin',
}) async {
  logger.info('ℹ️ Pushing $branchName to $remote');
  await _run(
    gitDir,
    ['push', '-u', remote, branchName],
    logger,
    'Failed to push $branchName',
  );
}

/// Tags [commitSha] as [tagName] and pushes it -- used for each package's
/// pub.dev-trust tag (this repo's pre-existing `<package>/v<version>`
/// convention), where an actual tag (not a branch) is what pub.dev's OIDC
/// trust and `publish-package.yml`'s trigger need. The `release-trigger/*`
/// marker tag is a separate case, pushed by raw `git tag`/`git push` from
/// `.gitlab-ci.yml`'s `push-release-trigger-tag` job, not through this
/// function.
Future<void> pushTag(
  GitDir gitDir,
  String tagName,
  String commitSha,
  Logger logger, {
  String remote = 'origin',
}) async {
  logger.info('ℹ️ Tagging $commitSha as $tagName');
  // Annotated, not lightweight -- some git configs (this repo's included)
  // sign tags, which requires a message; `git tag <name> <sha>` alone then
  // fails with "no tag message?".
  await _run(
    gitDir,
    ['tag', '-a', '-m', tagName, tagName, commitSha],
    logger,
    'Failed to create tag $tagName',
  );
  await _run(
    gitDir,
    ['push', remote, tagName],
    logger,
    'Failed to push tag $tagName',
  );
}

/// Pushes [commitSha] as the tip of [branchName] on [remote], without
/// needing a local branch or checkout: `git push {remote} {sha}:refs/heads/
/// {branchName}`. Used for `release-content/*`: it has to point at commit A
/// specifically, which is no longer `HEAD` by the time commit B (and
/// possibly more) have landed on top of it.
///
/// [force] is for moving an already-pushed branch to a new commit; the
/// first push (from `prepare_release.dart`) never needs it, since the
/// branch doesn't exist yet.
Future<void> pushBranchAt(
  GitDir gitDir,
  String branchName,
  String commitSha,
  Logger logger, {
  String remote = 'origin',
  bool force = false,
}) async {
  logger.info('ℹ️ Pushing $commitSha as $branchName');
  await _run(
    gitDir,
    [
      'push',
      if (force) '--force',
      remote,
      '$commitSha:refs/heads/$branchName',
    ],
    logger,
    'Failed to push $branchName at $commitSha',
  );
}

/// Whether [ancestorSha] is already reachable from [ref] -- `git merge-base
/// --is-ancestor`. Used as the backport's idempotency check: if commit A is
/// already an ancestor of `develop`/`v4`, a prior run already backported it
/// and `publish-release.yml` shouldn't open a second PR.
///
/// Returns `false` (not an error) for "no, not an ancestor" -- that's the
/// expected, common result, not a failure; only a genuine git error (e.g.
/// [ref] doesn't exist locally) throws.
Future<bool> isAncestor(
  GitDir gitDir,
  String ancestorSha,
  String ref,
  Logger logger,
) async {
  // `GitDir.runCommand` throws on any non-zero exit code, but `--is-ancestor`
  // uses exit code 1 to mean "no" -- a normal result, not a failure -- so
  // this has to shell out directly rather than go through `_run`/
  // `runCommand`, to see that exit code instead of an exception.
  final result = await Process.run('git', [
    'merge-base',
    '--is-ancestor',
    ancestorSha,
    ref,
  ], workingDirectory: gitDir.path);
  if (result.exitCode == 0) return true;
  if (result.exitCode == 1) return false;
  logger.shout(
    '❌ Failed to check ancestry of $ancestorSha in $ref: ${result.stderr}',
  );
  throw GitReleaseActionError(
    'Failed to check ancestry of $ancestorSha in $ref: ${result.stderr}',
  );
}
