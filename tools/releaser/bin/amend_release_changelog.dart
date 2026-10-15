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
//   1. Refuses if the working tree's diff is empty, or if it touches
//      anything other than a real workspace package's CHANGELOG.md.
//   2. Refuses if the release-prep PR this run would edit doesn't exist
//      yet, targets a support branch (no content commit to amend there), its
//      body has no "Content commit" line (see `manifest.dart`),
//      HEAD isn't commit B sitting on commit A (directly, or with the PR's
//      target branch merged in between), a touched package isn't actually
//      part of this release per the PR's versions table, or either remote
//      ref has moved past what's checked out here (another reviewer's push,
//      or a concurrent amend run) -- all still checked before anything is
//      mutated.
//   3. Amends commit A in place with the hand-edit.
//   4. Rebuilds the release-prep branch the way `prepare_release.dart` first
//      assembled it: from the amended commit A, merge the PR's target branch,
//      then re-apply commit B. Replaying B alone would drop that merge.
//   5. Force-moves the `release-content/*` branch and the release-prep branch,
//      each leased against the tip captured in step 2, in one atomic push.
//   6. Rewrites the open release-prep PR's body, swapping every occurrence
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
import 'package:releaser/git/release_publisher.dart';
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
  if (isSupportBranch(pr.baseRef)) {
    throw StateError(
      'This release has no content commit to amend (support-branch releases '
      'never split commit A from commit B) -- fix CHANGELOG.md directly and '
      'amend the single commit yourself.',
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

  await _checkShape(gitDir, originalContentCommit);

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

  final originalPublishPrep = localHead;
  final stashSha = await stashPush(
    gitDir,
    _log,
    'amend_release_changelog_${DateTime.now().microsecondsSinceEpoch}',
  );

  final String newContentCommit;
  try {
    final amended = await _amendContentCommit(
      gitDir,
      stashSha,
      workingBranch: workingBranch,
      originalContentCommit: originalContentCommit,
    );
    newContentCommit = await _rebuildReleaseBranch(
      gitDir,
      amended: amended,
      originalPublishPrep: originalPublishPrep,
      workingBranch: workingBranch,
      contentBranchName: contentBranchName,
      prBase: pr.baseRef,
      expectedRemoteTip: expectedRemoteTip,
      expectedContentTip: expectedContentTip,
    );
  } catch (e) {
    _log.shout(
      '❌ Failed to amend commit A -- stash $stashSha was left in place, and '
      '$workingBranch was not pushed. Run `git checkout $workingBranch` '
      'followed by `git stash apply $stashSha` to retry by hand: $e',
    );
    await tryCheckoutBranch(gitDir, workingBranch, _log);
    rethrow;
  }
  await stashDrop(gitDir, _log, stashSha);

  _log.info(
    'ℹ️ Commit A: $originalContentCommit -> $newContentCommit. Rebuilt '
    '$workingBranch on top of it.',
  );

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

/// Refuses unless HEAD is commit B sitting directly on [contentCommit], or
/// on a merge commit whose first parent is [contentCommit] -- the two shapes
/// `prepare_release.dart` produces.
Future<void> _checkShape(GitDir gitDir, String contentCommit) async {
  final parents = (await gitDir.runCommand([
    'rev-list',
    '--parents',
    '-n',
    '1',
    'HEAD',
  ])).stdout.toString().trim().split(' ');
  // [HEAD, its parents...]
  if (parents.length != 2) {
    throw StateError(
      'Expected HEAD to be the single-parent publish-prep commit, found a '
      'commit with ${parents.length - 1} parents. This tool only supports '
      'the standard release-prep shape.',
    );
  }
  final below = parents[1];
  if (below == contentCommit) return;

  final belowParents = (await gitDir.runCommand([
    'rev-list',
    '--parents',
    '-n',
    '1',
    below,
  ])).stdout.toString().trim().split(' ');
  if (belowParents.length == 3 && belowParents[1] == contentCommit) return;

  throw StateError(
    'Expected HEAD to be the publish-prep commit on top of commit A '
    '($contentCommit), optionally with the target branch merged in between. '
    'This tool only supports that release-prep shape.',
  );
}

/// Amends commit A with the stashed hand-edit and returns the amended
/// commit's SHA, leaving it checked out (detached).
Future<String> _amendContentCommit(
  GitDir gitDir,
  String stashSha, {
  required String workingBranch,
  required String originalContentCommit,
}) async {
  await checkoutRef(gitDir, originalContentCommit, _log);
  await stashApply(gitDir, _log, stashSha);
  await stageAll(gitDir, _log);
  return amendCommit(gitDir, _log);
}

/// Reassembles [workingBranch] on top of [amended] -- merge the PR's target,
/// then commit B again -- pushes it and [contentBranchName], and only then
/// moves the local [workingBranch] onto the result. Returns commit A's SHA.
Future<String> _rebuildReleaseBranch(
  GitDir gitDir, {
  required String amended,
  required String originalPublishPrep,
  required String workingBranch,
  required String contentBranchName,
  required String prBase,
  required String expectedRemoteTip,
  required String expectedContentTip,
}) async {
  final fetch = await Process.run('git', [
    'fetch',
    'origin',
    '+refs/heads/$prBase:refs/remotes/origin/$prBase',
  ], workingDirectory: gitDir.path);
  if (fetch.exitCode != 0) {
    throw StateError('git fetch origin $prBase failed: ${fetch.stderr}');
  }

  // Still detached on the amended commit A: [workingBranch] stays on the
  // original commit B until the push below succeeds, so a failure anywhere
  // here leaves the reviewer's branch untouched.
  await ReleasePublisher(
    commitHeadless: false,
  ).mergeRemoteBranchInto(gitDir, workingBranch, prBase, _log);
  await cherryPick(gitDir, originalPublishPrep, _log);

  final head = (await gitDir.currentBranch()).sha;
  await forcePushRefsAtomic(gitDir, [
    LeasedRefUpdate(
      branchName: contentBranchName,
      commitSha: amended,
      expectedTip: expectedContentTip,
    ),
    LeasedRefUpdate(
      branchName: workingBranch,
      commitSha: head,
      expectedTip: expectedRemoteTip,
    ),
  ], _log);
  await _checkoutNewBranchAt(gitDir, workingBranch, head);
  return amended;
}

Future<void> _checkoutNewBranchAt(
  GitDir gitDir,
  String branch,
  String sha,
) async {
  final result = await gitDir.runCommand([
    'checkout',
    '-B',
    branch,
    sha,
  ], throwOnError: false);
  if (result.exitCode != 0) {
    throw StateError('Failed to check out $branch at $sha: ${result.stderr}');
  }
}
