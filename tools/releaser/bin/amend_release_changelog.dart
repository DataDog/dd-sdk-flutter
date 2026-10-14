// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// Run by a reviewer, on a checked-out release-prep branch, after hand-editing
// a package's CHANGELOG.md to fix a mistake -- folds that edit into commit A
// instead of leaving it to drift from what `publish_release.dart` later
// backports.
//
// Does, in order -- cheap, purely local checks before anything that touches
// the network, so a plain mistake (wrong branch, wrong file, no changes at
// all) never costs a `gh` round-trip:
//   1. Refuses if run from a support branch (no content commit to amend
//      there), if the working tree's diff is empty, or if it touches
//      anything other than a real workspace package's CHANGELOG.md.
//   2. Refuses if the release-prep PR this run would edit doesn't exist
//      yet, its body has no "Content commit" line (see `manifest.dart`),
//      HEAD isn't exactly one commit (B) past that commit, a touched
//      package isn't actually part of this release per the PR's versions
//      table, or either remote ref has moved past what's checked out here
//      (another reviewer's push, or a concurrent amend run) -- all still
//      checked before anything is mutated.
//   3. Amends commit A in place with the hand-edit, then replays commit B
//      on top of the amended commit.
//   4. Atomically force-moves the `release-content/*` branch and the
//      release-prep branch together, each leased against the tip captured in
//      step 2 -- so a concurrent amend run can't interleave into a state
//      where one ref reflects this run and the other reflects the other run.
//   5. Rewrites the open release-prep PR's body, swapping every occurrence
//      of the old commit A SHA for the new one (including the "Content
//      commit" line itself).

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
import 'package:releaser/package_discovery.dart';
import 'package:releaser/publish_rules.dart';

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
  final currentBranch = await gitDir.currentBranch();
  final workingBranch = currentBranch.branchName;
  final localHead = currentBranch.sha;

  if (isPatchReleaseBranch(workingBranch)) {
    throw StateError(
      'This release has no content commit to amend (support-branch releases '
      'never split commit A from commit B) -- fix CHANGELOG.md directly and '
      'amend the single commit yourself.',
    );
  }

  // Local-only checks, run before any network call.
  final changedFiles = await _checkChangedFilesAreRealChangelogs(gitDir);

  // The release-prep PR for this branch.
  final pr = await github.findOpenPullRequestByHead(_log, workingBranch);
  if (pr == null) {
    throw StateError(
      'No open PR found with head $workingBranch -- expected the '
      'release-prep PR to already be open before amending anything.',
    );
  }
  final originalContentCommit = parseContentCommit(pr.body);
  if (originalContentCommit == null) {
    throw StateError(
      'PR #${pr.number}\'s body has no "Content commit" line -- not a '
      'release-prep PR for a mainline/pre-release run?',
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

  await _checkChangelogsAreReleasing(gitDir, changedFiles, pr.body);

  // The remote tip to lease the force-push below against.
  final expectedRemoteTip = await remoteTipFor(gitDir, workingBranch, _log);
  if (expectedRemoteTip != localHead) {
    throw StateError(
      '$workingBranch is at $expectedRemoteTip on origin, but this checkout '
      'is at $localHead -- someone else pushed to it since this checkout '
      'was made. Pull and re-run rather than risk overwriting their commit.',
    );
  }
  final expectedContentTip = await remoteTipFor(
    gitDir,
    contentBranchName,
    _log,
  );
  if (expectedContentTip != originalContentCommit) {
    throw StateError(
      '$contentBranchName is at $expectedContentTip on origin, not the '
      'commit A this manifest expects ($originalContentCommit) -- another '
      'amend run already moved it. Re-run against the current state rather '
      'than risk overwriting it.',
    );
  }

  // Count of the content-commit SHA's occurrences in the PR body, for the
  // final log message.
  final occurrences = RegExp(
    RegExp.escape(originalContentCommit),
  ).allMatches(pr.body).length;

  final newContentCommit = await _amendContentCommit(
    gitDir,
    workingBranch: workingBranch,
    originalContentCommit: originalContentCommit,
  );

  _log.info(
    'ℹ️ Commit A: $originalContentCommit -> $newContentCommit. Replayed '
    'commit B on top.',
  );

  final newHead = (await gitDir.currentBranch()).sha;
  await forcePushRefsAtomic(gitDir, [
    LeasedRefUpdate(
      branchName: contentBranchName,
      commitSha: newContentCommit,
      expectedTip: expectedContentTip,
    ),
    LeasedRefUpdate(
      branchName: workingBranch,
      commitSha: newHead,
      expectedTip: expectedRemoteTip,
    ),
  ], _log);

  // Swaps the old content-commit SHA for the new one everywhere in the PR
  // body, including the "Content commit" line itself.
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

/// Refuses if the working tree's diff is empty, or touches anything other
/// than the `CHANGELOG.md` of a real workspace package. Doesn't check
/// whether a touched package is part of *this* release; see
/// [_checkChangelogsAreReleasing] for that. Returns the changed files.
Future<List<String>> _checkChangedFilesAreRealChangelogs(GitDir gitDir) async {
  final changedFiles = await changedFilesAgainst(gitDir, 'HEAD', _log);
  if (changedFiles.isEmpty) {
    throw StateError(
      'No working tree changes to fold into commit A -- hand-edit a '
      "package's CHANGELOG.md first.",
    );
  }

  final allPackagePaths = (await discoverPackages(
    gitDir.path,
  )).expand((g) => g.members).map((pkg) => pkg.relativePath).toSet();

  final ineligible = changedFiles.where((f) {
    if (p.basename(f) != _eligibleBasename) return true;
    final dir = p.dirname(f);
    return !allPackagePaths.any((pkgPath) => p.equals(dir, pkgPath));
  }).toList();

  if (ineligible.isNotEmpty) {
    throw StateError(
      'Refusing to amend -- this tool only amends a workspace package\'s '
      '$_eligibleBasename. These changed files are outside that: '
      '${ineligible.join(', ')}',
    );
  }

  return changedFiles;
}

/// Refuses if any of [changedFiles] belongs to a package that isn't part of
/// this release, per [prBody]'s versions table.
Future<void> _checkChangelogsAreReleasing(
  GitDir gitDir,
  List<String> changedFiles,
  String prBody,
) async {
  final releasingPackages = parseVersionsTable(
    prBody,
  ).map((row) => row.package).toSet();
  final releasingPackagePaths = (await discoverPackages(gitDir.path))
      .expand((g) => g.members)
      .where((pkg) => releasingPackages.contains(pkg.name))
      .map((pkg) => pkg.relativePath)
      .toSet();

  final ineligible = changedFiles.where((f) {
    final dir = p.dirname(f);
    return !releasingPackagePaths.any((pkgPath) => p.equals(dir, pkgPath));
  }).toList();

  if (ineligible.isNotEmpty) {
    throw StateError(
      'Refusing to amend -- these changed files belong to a package that '
      'is not part of this release: ${ineligible.join(', ')}',
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
