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

/// Stages everything under [gitDir] without committing -- used to fold a
/// working-tree edit into an `amendCommit` call rather than a fresh commit.
Future<void> stageAll(GitDir gitDir, Logger logger) async {
  await _run(gitDir, ['add', '.'], logger, 'Failed to stage changes');
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
    ['push', if (force) '--force', remote, '$commitSha:refs/heads/$branchName'],
    logger,
    'Failed to push $branchName at $commitSha',
  );
}

/// Derives a `release-content/{id}` branch name from its paired
/// `release-prep/{id}` branch -- shared by `prepare_release.dart` (which
/// creates it) and `amend_release_changelog.dart` (which force-moves it via
/// [pushBranchAt] after a changelog fixup), so the naming stays in one
/// place.
String contentBranchNameFor(String workingBranch) {
  const prefix = 'release-prep/';
  if (!workingBranch.startsWith(prefix)) {
    throw StateError(
      '$workingBranch is not a release-prep branch -- it has no paired '
      'release-content branch.',
    );
  }
  return 'release-content/${workingBranch.substring(prefix.length)}';
}

/// Repo-relative paths that differ from [ref] in the working tree, staged
/// or not, plus any untracked file -- used by `amend_release_changelog.dart`
/// to check a hand-edit's diff stays within commit A's eligible files
/// before folding it in.
Future<List<String>> changedFilesAgainst(
  GitDir gitDir,
  String ref,
  Logger logger,
) async {
  final tracked = await _run(
    gitDir,
    ['diff', '--name-only', ref],
    logger,
    'Failed to diff working tree against $ref',
  );
  final untracked = await _run(
    gitDir,
    ['ls-files', '--others', '--exclude-standard'],
    logger,
    'Failed to list untracked files',
  );
  return {
    ...(tracked.stdout as String).split('\n').where((l) => l.isNotEmpty),
    ...(untracked.stdout as String).split('\n').where((l) => l.isNotEmpty),
  }.toList();
}

/// `git stash push -u`, returning the created stash's commit SHA (not a
/// `stash@{n}` index, which shifts under concurrent stash activity) so
/// [stashApply]/[stashDrop] can re-find it later by content rather than by
/// position.
Future<String> stashPush(GitDir gitDir, Logger logger, String message) async {
  await _run(
    gitDir,
    ['stash', 'push', '-u', '-m', message],
    logger,
    'Failed to stash working tree changes',
  );
  return _findStash(gitDir, logger, message);
}

Future<String> _findStash(GitDir gitDir, Logger logger, String message) async {
  final list = await _run(
    gitDir,
    ['stash', 'list', '--format=%H %gs'],
    logger,
    'Failed to list stashes',
  );
  final line = (list.stdout as String)
      .split('\n')
      .firstWhere((l) => l.contains(message), orElse: () => '');
  if (line.isEmpty) {
    throw GitReleaseActionError('No stash entry found for "$message".');
  }
  return line.split(' ').first;
}

/// Applies (not pops) the stash at [stashSha] -- directly by its commit SHA
/// (which `git stash apply`, unlike `git stash drop`, accepts), so this
/// never has to resolve a `stash@{n}` index that a concurrent `git stash
/// push` elsewhere could shift out from under it.
Future<void> stashApply(GitDir gitDir, Logger logger, String stashSha) async {
  await _run(
    gitDir,
    ['stash', 'apply', stashSha],
    logger,
    'Failed to apply stash $stashSha',
  );
}

/// Drops the stash at [stashSha]. A no-op if it's already gone.
///
/// `git stash drop` (unlike [stashApply]) only accepts a `stash@{n}` index,
/// not a raw SHA, so this still has to resolve one -- but re-verifies the
/// resolved index still points at [stashSha] immediately before dropping it,
/// so a concurrent `git stash push` that shifted the stack in between causes
/// a loud failure instead of silently dropping the wrong entry.
Future<void> stashDrop(GitDir gitDir, Logger logger, String stashSha) async {
  final ref = await _stashRefFor(
    gitDir,
    logger,
    stashSha,
    ifMissing: () => null,
  );
  if (ref == null) return;

  final resolved = await _run(
    gitDir,
    ['rev-parse', '$ref^{commit}'],
    logger,
    'Failed to resolve $ref before dropping it',
  );
  if ((resolved.stdout as String).trim() != stashSha) {
    throw GitReleaseActionError(
      '$ref no longer points at $stashSha (something else changed the '
      'stash stack) -- refusing to drop it.',
    );
  }

  await _run(
    gitDir,
    ['stash', 'drop', ref],
    logger,
    'Failed to drop stash $ref',
  );
}

Future<String?> _stashRefFor(
  GitDir gitDir,
  Logger logger,
  String stashSha, {
  String? Function()? ifMissing,
}) async {
  final list = await _run(
    gitDir,
    ['stash', 'list', '--format=%H %gd'],
    logger,
    'Failed to list stashes',
  );
  final line = (list.stdout as String)
      .split('\n')
      .firstWhere((l) => l.startsWith(stashSha), orElse: () => '');
  if (line.isEmpty) {
    if (ifMissing != null) return ifMissing();
    throw GitReleaseActionError('Stash $stashSha no longer exists.');
  }
  return line.split(' ').last;
}

/// Checks out [ref] directly (detached, if [ref] is a SHA) -- used to move
/// onto commit A before amending it.
Future<void> checkoutRef(GitDir gitDir, String ref, Logger logger) async {
  await _run(gitDir, ['checkout', ref], logger, 'Failed to checkout $ref');
}

/// `git commit --amend --no-edit`, returning the amended commit's new SHA.
Future<String> amendCommit(GitDir gitDir, Logger logger) async {
  await _run(
    gitDir,
    ['commit', '--amend', '--no-edit'],
    logger,
    'Failed to amend commit',
  );
  final result = await _run(
    gitDir,
    ['rev-parse', 'HEAD'],
    logger,
    'Failed to resolve HEAD after amend',
  );
  return (result.stdout as String).trim();
}

/// `git rebase --onto newBase oldBase branch` -- replays [branch]'s commits
/// after [oldBase] onto [newBase], moving [branch]'s ref and leaving it
/// checked out. Used to replay commit B onto an amended commit A.
Future<void> rebaseOnto(
  GitDir gitDir,
  String newBase,
  String oldBase,
  String branch,
  Logger logger,
) async {
  await _run(
    gitDir,
    ['rebase', '--onto', newBase, oldBase, branch],
    logger,
    'Failed to rebase $branch onto $newBase',
  );
}

/// Number of commits reachable from [to] but not [from] -- `git rev-list
/// --count from..to`.
Future<int> commitCountBetween(
  GitDir gitDir,
  String from,
  String to,
  Logger logger,
) async {
  final result = await _run(
    gitDir,
    ['rev-list', '--count', '$from..$to'],
    logger,
    'Failed to count commits between $from and $to',
  );
  return int.parse((result.stdout as String).trim());
}

/// `git fetch`es [branchName] and returns its current tip on [remote] --
/// call this *before* any local rewriting starts, then hand the result to
/// [forcePushBranch] as `expectedTip` so the lease it checks reflects the
/// remote as it was when the caller began, not whatever it's drifted to by
/// the time the push actually happens.
Future<String> remoteTipFor(
  GitDir gitDir,
  String branchName,
  Logger logger, {
  String remote = 'origin',
}) async {
  await _run(
    gitDir,
    ['fetch', remote, branchName],
    logger,
    'Failed to fetch $branchName',
  );
  final result = await _run(
    gitDir,
    ['rev-parse', 'FETCH_HEAD'],
    logger,
    'Failed to resolve fetched $branchName',
  );
  return (result.stdout as String).trim();
}

/// `git push --force-with-lease` for [branchName]'s current tip, refusing if
/// [remote]'s copy of [branchName] is no longer at [expectedTip] -- unlike a
/// plain `--force`. [expectedTip] is checked directly against the remote's
/// actual value at push time, so, unlike re-fetching right before pushing,
/// it can't be defeated by another update landing on [branchName] between
/// when the caller captured [expectedTip] (via [remoteTipFor], before doing
/// any local rewriting) and when this push happens.
Future<void> forcePushBranch(
  GitDir gitDir,
  String branchName,
  Logger logger, {
  required String expectedTip,
  String remote = 'origin',
}) async {
  logger.info('ℹ️ Force-pushing $branchName to $remote');
  await _run(
    gitDir,
    [
      'push',
      '--force-with-lease=$branchName:$expectedTip',
      remote,
      branchName,
    ],
    logger,
    'Failed to force-push $branchName',
  );
}

/// Best-effort `git rebase --abort` -- swallows the error `git` raises when
/// there's nothing to abort, so callers can call this unconditionally from a
/// catch block without checking `.git/rebase-*` state themselves first.
Future<void> abortRebaseIfInProgress(GitDir gitDir, Logger logger) async {
  final result = await Process.run('git', [
    'rebase',
    '--abort',
  ], workingDirectory: gitDir.path);
  if (result.exitCode != 0) {
    logger.fine('ℹ️ Nothing to abort: ${result.stderr}');
  }
}

/// Best-effort `git checkout [branch]` -- used to try to leave a reviewer
/// back on their working branch after a failure partway through detached-HEAD
/// surgery; swallows its own error since the caller is already mid-failure
/// and a clearer message about the original error matters more than this.
Future<void> tryCheckoutBranch(
  GitDir gitDir,
  String branch,
  Logger logger,
) async {
  final result = await Process.run('git', [
    'checkout',
    branch,
  ], workingDirectory: gitDir.path);
  if (result.exitCode != 0) {
    logger.shout(
      '⚠️ Also failed to switch back to $branch -- you are left on a '
      'detached HEAD: ${result.stderr}',
    );
  }
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
