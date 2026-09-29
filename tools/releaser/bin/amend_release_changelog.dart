// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// Run by a reviewer, on a checked-out release-prep branch, after hand-editing
// a package's CHANGELOG.md to fix a mistake -- folds that edit into commit A
// instead of leaving it to drift from what `publish_release.dart` later
// backports.
//
// Does, in order:
//   1. Refuses if the working tree's diff touches anything other than a
//      workspace package's CHANGELOG.md, HEAD isn't exactly one commit (B)
//      past commit A, or the release-prep PR this run would edit doesn't
//      exist yet -- all checked before anything is mutated, so a refusal
//      never leaves a half-amended branch behind.
//   2. Amends commit A in place with the hand-edit, then replays commit B on
//      top of the amended commit and rewrites its manifest.json
//      `contentCommit` to match.
//   3. Force-moves the `release-content/*` branch to the new commit A, and
//      force-pushes the release-prep branch itself.
//   4. Rewrites the open release-prep PR's body, swapping every occurrence
//      of the old commit A SHA for the new one.

import 'dart:io';

import 'package:args/args.dart';
import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:releaser/cli_logging.dart';
import 'package:releaser/git/git_dir.dart';
import 'package:releaser/git/release_git.dart';
import 'package:releaser/github_cmd_wrapper.dart';
import 'package:releaser/manifest.dart';

final _log = Logger('amend_release_changelog');

/// The only basename a hand-edit is allowed to touch -- this tool exists
/// specifically for changelog fixes, not for re-running any other part of
/// commit A (a version bump, a native SDK pin, ...), which would need its
/// own re-validation this tool doesn't do.
const _eligibleBasename = 'CHANGELOG.md';

Future<void> main(List<String> arguments) async {
  configureCliLogging();

  final argParser = ArgParser()
    ..addOption(
      'repo-root',
      help: 'Repo root to run against. Defaults to the current directory.',
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

  try {
    await amendReleaseChangelog(
      gitDir: gitDir,
      github: GithubCommandWrapper(gitDir.path),
    );
  } catch (e) {
    _log.shout(e is StateError ? '❌ ${e.message}' : '❌ $e');
    exitCode = 1;
  }
}

Future<void> amendReleaseChangelog({
  required GitDir gitDir,
  required GithubCommandWrapper github,
}) async {
  final workingBranch = (await gitDir.currentBranch()).branchName;

  final manifest = await readManifest(gitDir.path);
  final originalContentCommit = manifest.contentCommit;
  if (originalContentCommit == null) {
    throw StateError(
      'This release has no content commit to amend (patch releases never '
      'split commit A from commit B) -- fix CHANGELOG.md directly and amend '
      'the single commit yourself.',
    );
  }
  final contentBranchName = contentBranchNameFor(workingBranch);

  final commitsAfterContent = await commitCountBetween(
    gitDir,
    originalContentCommit,
    'HEAD',
    _log,
  );
  if (commitsAfterContent != 1) {
    throw StateError(
      'Expected HEAD to be exactly one commit (publish-prep) after commit A '
      '($originalContentCommit), found $commitsAfterContent. This tool only '
      'supports the standard two-commit release-prep shape.',
    );
  }

  await _checkEligibleFiles(gitDir, manifest);

  // Captured now, before any local rewriting, so the force-push lease below
  // is checked against the remote as it was when this run started rather
  // than being silently refreshed to whatever it's drifted to by push time.
  final expectedRemoteTip = await remoteTipFor(gitDir, workingBranch, _log);

  // Everything below mutates something -- from here on a failure should
  // either be cleanly retryable or leave a clear recovery path, never a
  // silent half-amended state. Confirming the PR we'll edit at the very end
  // actually exists *now*, before any git surgery, means we never force-move
  // real branches only to discover afterwards there's nothing to update
  // their PR link to.
  final pr = await github.findOpenPullRequestByHead(_log, workingBranch);
  if (pr == null) {
    throw StateError(
      'No open PR found with head $workingBranch -- expected the '
      'release-prep PR to already be open before amending anything.',
    );
  }
  final occurrences = RegExp(
    RegExp.escape(originalContentCommit),
  ).allMatches(pr.body).length;
  if (occurrences == 0) {
    throw StateError(
      'PR #${pr.number}\'s body does not contain $originalContentCommit '
      'anywhere -- either it was already amended, or this is not the PR '
      '`release_pr.dart` wrote for this branch. Refusing rather than risk '
      'editing the wrong body.',
    );
  }

  final newContentCommit = await _amendContentCommit(
    gitDir,
    workingBranch: workingBranch,
    originalContentCommit: originalContentCommit,
  );

  await writeManifest(
    gitDir.path,
    ReleaseManifest(
      contentCommit: newContentCommit,
      packages: manifest.packages,
    ),
  );
  await stageAll(gitDir, _log);
  await amendCommit(gitDir, _log);

  _log.info(
    'ℹ️ Commit A: $originalContentCommit -> $newContentCommit. Replayed '
    'commit B on top.',
  );

  await pushBranchAt(
    gitDir,
    contentBranchName,
    newContentCommit,
    _log,
    force: true,
  );
  await forcePushBranch(
    gitDir,
    workingBranch,
    _log,
    expectedTip: expectedRemoteTip,
  );

  // The one step past this point that isn't itself retryable by re-running
  // the tool (the working tree is clean again by now, so a second run would
  // just refuse with "nothing to amend") -- if this fails, both branches are
  // already correct on the remote and only the PR body is stale; fix it by
  // hand with the SHA logged below.
  final newBody = pr.body.replaceAll(originalContentCommit, newContentCommit);
  try {
    await github.editPullRequestBody(_log, pr.number, newBody);
  } catch (e) {
    _log.shout(
      '❌ Both branches were force-pushed with the new commit A '
      '($newContentCommit), but updating PR #${pr.number}\'s body failed: '
      '$e. Fix its links to $originalContentCommit by hand.',
    );
    rethrow;
  }

  _log.info(
    '✅ Amended commit A, force-pushed $workingBranch and '
    '$contentBranchName, and updated PR #${pr.number} '
    '($occurrences link(s) rewritten).',
  );
}

/// Refuses if the working tree's diff touches anything other than the
/// `CHANGELOG.md` of a package that's actually part of this release --
/// checked by basename *and* by directory, so a same-named file elsewhere in
/// the repo (this tool's own `CHANGELOG.md`, if it had one) can't slip
/// through, and so can every other commit-A file (`pubspec.yaml`,
/// `NATIVE_SDK_VERSIONS.md`, ...) even though they're legitimately part of
/// commit A -- this tool is deliberately changelog-only. Restricted to
/// [manifest]'s packages rather than every workspace package, since a
/// hand-edit to an unreleased package's changelog would otherwise get folded
/// in, force-pushed, and backported despite that package being absent from
/// the manifest, versions table, and publish set.
Future<void> _checkEligibleFiles(
  GitDir gitDir,
  ReleaseManifest manifest,
) async {
  final changedFiles = await changedFilesAgainst(gitDir, 'HEAD', _log);
  if (changedFiles.isEmpty) {
    throw StateError(
      'No working tree changes to fold into commit A -- hand-edit a '
      "package's CHANGELOG.md first.",
    );
  }

  final packagePaths = manifest.packages.map((e) => e.relativePath).toSet();

  final ineligible = changedFiles.where((f) {
    if (p.basename(f) != _eligibleBasename) return true;
    final dir = p.dirname(f);
    return !packagePaths.any((pkgPath) => p.equals(dir, pkgPath));
  }).toList();

  if (ineligible.isNotEmpty) {
    throw StateError(
      'Refusing to amend -- this tool only amends a workspace package\'s '
      '$_eligibleBasename. These changed files are outside that: '
      '${ineligible.join(', ')}',
    );
  }
}

/// Amends commit A with whatever's currently in the working tree/stash,
/// replays commit B on top via `git rebase --onto`, and returns the new
/// commit A SHA. Leaves [workingBranch] checked out on success; makes a
/// best effort to leave the caller back on [workingBranch] on failure too,
/// after logging exactly what's recoverable and how.
Future<String> _amendContentCommit(
  GitDir gitDir, {
  required String workingBranch,
  required String originalContentCommit,
}) async {
  final stashSha = await stashPush(
    gitDir,
    _log,
    'amend_release_changelog_${DateTime.now().microsecondsSinceEpoch}',
  );

  String newContentCommit;
  try {
    await checkoutRef(gitDir, originalContentCommit, _log);
    await stashApply(gitDir, _log, stashSha);
    await stageAll(gitDir, _log);
    newContentCommit = await amendCommit(gitDir, _log);
  } catch (e) {
    _log.shout(
      '❌ Failed to amend commit A -- stash $stashSha was left in place. '
      'Resolve any conflict, or run `git checkout $workingBranch` followed '
      'by `git stash apply $stashSha` to retry by hand: $e',
    );
    await tryCheckoutBranch(gitDir, workingBranch, _log);
    rethrow;
  }

  try {
    await rebaseOnto(
      gitDir,
      newContentCommit,
      originalContentCommit,
      workingBranch,
      _log,
    );
  } catch (e) {
    _log.shout(
      '❌ Replaying commit B onto the amended commit A ($newContentCommit) '
      'failed -- $workingBranch was not updated, but the amended commit A '
      'still exists (recoverable via `git reflog` if `git rebase --abort` '
      'below loses it): $e',
    );
    await abortRebaseIfInProgress(gitDir, _log);
    await tryCheckoutBranch(gitDir, workingBranch, _log);
    rethrow;
  }

  // Only safe to drop now that the amended commit A is reachable from
  // workingBranch (via the rebased commit B) -- dropping it any earlier
  // risks losing the hand-edit to nothing but the reflog if the rebase
  // above fails.
  await stashDrop(gitDir, _log, stashSha);
  return newContentCommit;
}
