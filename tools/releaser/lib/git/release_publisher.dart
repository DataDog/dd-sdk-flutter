// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:git/git.dart';
import 'package:logging/logging.dart';

import 'release_git.dart';

/// How release branches get from the local checkout to GitHub.
///
/// Every commit has to be signed. A local run does that through the user's
/// own git config and pushes with plain `git push` and a local `git merge`.
/// With [commitHeadless] (CI) the pushes go through `commit-headless` and the
/// merge through GitHub's merges API instead, since a CI runner has no
/// signing key of its own: `commit-headless` re-creates each local commit
/// through the GitHub API, and GitHub signs the merge commit.
///
/// Either way a push leaves the local branch at exactly what the remote now
/// has, so every SHA the caller reads afterwards -- the one recorded in the
/// release PR's "Content commit" line included -- is the remote's.
class ReleasePublisher {
  final bool commitHeadless;

  /// `owner/repo`. Required when [commitHeadless].
  final String? repoSlug;

  /// The `commit-headless` and `gh` executables to run; tests substitute
  /// fakes.
  final String commitHeadlessBinary;
  final String ghBinary;

  ReleasePublisher({
    required this.commitHeadless,
    this.repoSlug,
    this.commitHeadlessBinary = 'commit-headless',
    this.ghBinary = 'gh',
  }) {
    if (commitHeadless && repoSlug == null) {
      throw ArgumentError('commit-headless needs a repoSlug.');
    }
  }

  /// Pushes the checked-out [branch], which doesn't exist on the remote yet
  /// and was created from [baseSha], and returns its tip on the remote.
  Future<String> pushNewBranch(
    GitDir gitDir,
    String branch,
    String baseSha,
    Logger logger,
  ) async {
    if (!commitHeadless) {
      await pushBranch(gitDir, branch, logger);
      return _head(gitDir);
    }
    return _commitHeadless(gitDir, branch, logger, baseSha, [
      '--head-sha',
      baseSha,
      '--create-branch',
    ]);
  }

  /// Pushes new local commits on the checked-out [branch], which already
  /// exists on the remote, and returns its tip on the remote.
  Future<String> pushCommits(
    GitDir gitDir,
    String branch,
    Logger logger,
  ) async {
    if (!commitHeadless) {
      await pushBranch(gitDir, branch, logger);
      return _head(gitDir);
    }
    return _commitHeadless(
      gitDir,
      branch,
      logger,
      await _remoteTip(gitDir, branch),
      const [],
    );
  }

  /// Merges `origin/[from]` into the checked-out [branch] and returns the new
  /// tip. With commit-headless, [branch] must be on the remote already.
  ///
  /// On a conflict the merge keeps [branch]'s side of everything, and
  /// `origin/[from]` stays an ancestor of the new tip. Plain git records [from]
  /// as the second parent. Through the API the second parent is a one-commit
  /// resolution branch whose parent is `origin/[from]`.
  Future<String> mergeRemoteBranchInto(
    GitDir gitDir,
    String branch,
    String from,
    Logger logger,
  ) async {
    if (!commitHeadless) {
      final merge = await gitDir.runCommand([
        'merge',
        '--no-edit',
        'origin/$from',
      ], throwOnError: false);
      if (merge.exitCode != 0) {
        await gitDir.runCommand(['merge', '--abort']);
        logger.warning(
          '⚠️ Merging origin/$from into $branch conflicted -- keeping this '
          'branch\'s side of every file. What $from carries beyond this '
          'branch is the previous release\'s publish-prep commit, which is '
          're-derived on top of this merge.',
        );
        await _run(gitDir, [
          'merge',
          '--no-edit',
          '-s',
          'ours',
          'origin/$from',
        ]);
      }
      return _head(gitDir);
    }

    logger.info('ℹ️ Merging $from into $branch via the GitHub API');
    // The branch's current tip is already verified (it came from a prior
    // commit-headless push), so a plain push can create the ref the API needs.
    await _run(gitDir, ['push', 'origin', 'HEAD:refs/heads/$branch']);
    var result = await _apiMerge(gitDir, branch, from);
    if (result.exitCode != 0) {
      final firstError = '${result.stderr}${result.stdout}'.trim();
      final conflicts = await _conflictingPaths(gitDir, from);
      if (conflicts.isEmpty) {
        throw GitReleaseActionError(
          'Merging $from into $branch through the GitHub API failed: '
          '$firstError',
        );
      }
      logger.warning(
        '⚠️ Merging $from into $branch conflicted in ${conflicts.length} '
        'file(s) -- keeping this branch\'s side of every file. What $from '
        'carries beyond this branch is the previous release\'s publish-prep '
        'commit, which is re-derived on top of this merge. GitHub answered: '
        '$firstError',
      );
      final resolution = await _pushResolution(gitDir, branch, from, logger);
      try {
        result = await _apiMerge(gitDir, branch, resolution);
      } finally {
        await _deleteRemoteBranch(gitDir, resolution, logger);
      }
      if (result.exitCode != 0) {
        throw GitReleaseActionError(
          'Merging $from into $branch through the GitHub API failed even '
          'after resolving its conflicts: ${result.stderr}${result.stdout}\n'
          '(First attempt: $firstError)',
        );
      }
    }
    await _run(gitDir, ['fetch', 'origin', branch]);
    await _run(gitDir, ['reset', '--hard', 'FETCH_HEAD']);
    return _head(gitDir);
  }

  /// `POST /merges`: merges [head] into [base]. GitHub signs the merge commit
  /// but cannot resolve conflicts.
  Future<ProcessResult> _apiMerge(GitDir gitDir, String base, String head) =>
      Process.run(ghBinary, [
        'api',
        '--method',
        'POST',
        'repos/$repoSlug/merges',
        '-f',
        'base=$base',
        '-f',
        'head=$head',
      ], workingDirectory: gitDir.path);

  /// The files a merge of `origin/[from]` into the checked-out branch
  /// conflicts in; empty when it merges cleanly.
  Future<List<String>> _conflictingPaths(GitDir gitDir, String from) async {
    final merge = await gitDir.runCommand([
      'merge',
      '--no-commit',
      '--no-ff',
      'origin/$from',
    ], throwOnError: false);
    try {
      if (merge.exitCode == 0) return const [];
      final result = await gitDir.runCommand([
        'diff',
        '--name-only',
        '--diff-filter=U',
      ]);
      return LineSplitter.split(
        result.stdout.toString(),
      ).where((path) => path.isNotEmpty).toList();
    } finally {
      await gitDir.runCommand(['merge', '--abort'], throwOnError: false);
    }
  }

  /// Creates a branch holding one commit on top of `origin/[from]` with
  /// [branch]'s exact tree, and returns its name.
  ///
  /// Merging that branch into [branch] can't conflict, because both sides then
  /// hold the same tree. The merge result is [branch]'s tree, and
  /// `origin/[from]` is reachable through the resolution commit's parent. Any
  /// other tree can still conflict: git pairs renamed files differently on
  /// each side.
  ///
  /// The commit is created with the REST API, reusing [branch]'s tree object on
  /// the remote. `commit-headless` rebuilds a commit from a file diff, and its
  /// GraphQL path records every file as a regular file (100644), so the tree it
  /// produces can differ from [branch]'s in file modes.
  ///
  /// Throws if GitHub does not sign the commit, since a branch that requires
  /// signed commits would reject the release PR.
  Future<String> _pushResolution(
    GitDir gitDir,
    String branch,
    String from,
    Logger logger,
  ) async {
    final resolution = 'merge-resolution/${branch.replaceAll('/', '-')}';
    final fromSha = (await gitDir.runCommand([
      'rev-parse',
      'origin/$from',
    ])).stdout.toString().trim();
    final tree = (await gitDir.runCommand([
      'rev-parse',
      'HEAD^{tree}',
    ])).stdout.toString().trim();

    final created = (await _gh(gitDir, [
      'repos/$repoSlug/git/commits',
      '-f',
      'message=chore(release): keep $branch\'s side of conflicts with $from',
      '-f',
      'tree=$tree',
      '-f',
      'parents[]=$fromSha',
      '--jq',
      '.sha + " " + (.verification.verified | tostring)',
    ])).split(' ');
    if (created.last != 'true') {
      throw GitReleaseActionError(
        'GitHub did not sign the conflict-resolution commit ${created.first}, '
        'and a branch that requires signed commits would reject the release '
        'PR. $branch is already pushed; merge $from into it from a local run '
        '(without --commit-headless), which signs with your own key.',
      );
    }
    await _gh(gitDir, [
      'repos/$repoSlug/git/refs',
      '-f',
      'ref=refs/heads/$resolution',
      '-f',
      'sha=${created.first}',
    ]);
    return resolution;
  }

  /// `gh api --method POST` for [args], returning stdout.
  Future<String> _gh(GitDir gitDir, List<String> args) async {
    final result = await Process.run(ghBinary, [
      'api',
      '--method',
      'POST',
      ...args,
    ], workingDirectory: gitDir.path);
    if (result.exitCode != 0) {
      throw GitReleaseActionError(
        'gh api ${args.first} failed: ${result.stderr}${result.stdout}',
      );
    }
    return result.stdout.toString().trim();
  }

  Future<void> _deleteRemoteBranch(
    GitDir gitDir,
    String branch,
    Logger logger,
  ) async {
    final result = await gitDir.runCommand([
      'push',
      'origin',
      '--delete',
      branch,
    ], throwOnError: false);
    if (result.exitCode != 0) {
      logger.warning(
        '⚠️ Could not delete the temporary branch $branch: ${result.stderr}',
      );
    }
  }

  /// Pushes the checked-out [branch] through `commit-headless`, then moves the
  /// local branch onto the commit it created and returns that commit's SHA.
  ///
  /// The sync is done here rather than with `commit-headless --reset`, which
  /// only warns and exits 0 when it can't reset (a dirty tree, or no remote
  /// matching the target repo). Anything that doesn't end with the local
  /// branch exactly on the remote's commit throws: a later step building on
  /// a SHA the remote doesn't have would only fail much later.
  Future<String> _commitHeadless(
    GitDir gitDir,
    String branch,
    Logger logger,
    String base,
    List<String> extraArgs,
  ) async {
    // commit-headless 2.0.x pushes the commits it is given on stdin, one SHA
    // per line, oldest first, rather than working out what is new itself.
    final commits = (await gitDir.runCommand([
      'rev-list',
      '--reverse',
      '$base..HEAD',
    ])).stdout.toString().trim();
    if (commits.isEmpty) {
      throw GitReleaseActionError(
        'Nothing to push to $branch: HEAD has no commits on top of $base.',
      );
    }

    logger.info('ℹ️ Pushing $branch through commit-headless');
    final process = await Process.start(commitHeadlessBinary, [
      'push',
      '-T',
      repoSlug!,
      '--branch',
      branch,
      ...extraArgs,
    ], workingDirectory: gitDir.path);
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.transform(utf8.decoder).join();
    try {
      process.stdin.writeln(commits);
      await process.stdin.close();
    } on IOException {
      // The tool exited without reading its input; its exit code says why.
    }
    final result = (
      exitCode: await process.exitCode,
      stdout: await stdout,
      stderr: await stderr,
    );
    if (result.exitCode != 0) {
      throw GitReleaseActionError(
        'commit-headless push of $branch failed: ${result.stderr}',
      );
    }

    // On success it prints only the SHA of the last commit it created.
    final pushedSha = result.stdout.trim().split('\n').last.trim();
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(pushedSha)) {
      throw GitReleaseActionError(
        'commit-headless push of $branch did not print a commit SHA: '
        '${result.stdout}',
      );
    }

    if ((await gitDir.currentBranch()).branchName != branch) {
      throw GitReleaseActionError(
        'Expected $branch to be checked out after pushing it through '
        'commit-headless.',
      );
    }
    await _run(gitDir, ['fetch', 'origin', branch]);
    final remoteTip = (await gitDir.runCommand([
      'rev-parse',
      'FETCH_HEAD',
    ])).stdout.toString().trim();
    if (remoteTip != pushedSha) {
      throw GitReleaseActionError(
        'commit-headless reported $pushedSha for $branch, but origin/$branch '
        'is at $remoteTip.',
      );
    }
    await _run(gitDir, ['reset', '--hard', pushedSha]);

    final head = await _head(gitDir);
    if (head != pushedSha) {
      throw GitReleaseActionError(
        'After pushing $branch through commit-headless, HEAD is $head, not '
        'the pushed $pushedSha.',
      );
    }
    return head;
  }

  /// The tip of [branch] on `origin`.
  Future<String> _remoteTip(GitDir gitDir, String branch) async {
    await _run(gitDir, ['fetch', 'origin', branch]);
    return (await gitDir.runCommand([
      'rev-parse',
      'FETCH_HEAD',
    ])).stdout.toString().trim();
  }

  Future<void> _run(GitDir gitDir, List<String> args) async {
    final result = await gitDir.runCommand(args, throwOnError: false);
    if (result.exitCode != 0) {
      throw GitReleaseActionError(
        'git ${args.join(' ')} failed: ${result.stderr}',
      );
    }
  }

  Future<String> _head(GitDir gitDir) async {
    final result = await gitDir.runCommand(['rev-parse', 'HEAD']);
    return (result.stdout as String).trim();
  }
}
