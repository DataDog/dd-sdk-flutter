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

/// Tags [commitSha] as [tagName] and pushes it -- used to keep commit A
/// fetchable by SHA after its `release-prep/*` branch is gone (this repo
/// auto-deletes a PR's head branch on merge), so Phase 2's backport can
/// still `git merge` it into the dev-line branch later regardless of which
/// merge strategy landed the release-prep PR.
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
