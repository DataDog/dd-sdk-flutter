// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

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
    return _commitHeadless(gitDir, branch, logger, [
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
    return _commitHeadless(gitDir, branch, logger, const []);
  }

  /// Merges `origin/[from]` into the checked-out [branch] and returns the new
  /// tip. With commit-headless, [branch] must be on the remote already.
  ///
  /// On a conflict, plain git retries with `-s ours`, keeping [branch]'s side
  /// of everything; GitHub's merges API has no such option, so commit-headless
  /// throws.
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
    final result = await Process.run(ghBinary, [
      'api',
      '--method',
      'POST',
      'repos/$repoSlug/merges',
      '-f',
      'base=$branch',
      '-f',
      'head=$from',
    ], workingDirectory: gitDir.path);
    // 204 (nothing to merge) prints nothing; success otherwise prints the
    // new commit.
    if (result.exitCode != 0) {
      throw GitReleaseActionError(
        'Merging $from into $branch through the GitHub API failed: '
        '${result.stderr}${result.stdout}\n'
        'If this is a merge conflict, the dev line edited lines the previous '
        'release\'s publish-prep commit also changed. The API cannot pick a '
        'side, but a local run (without --commit-headless) resolves it by '
        'keeping this branch\'s side and re-deriving that commit.',
      );
    }
    await _run(gitDir, ['fetch', 'origin', branch]);
    await _run(gitDir, ['reset', '--hard', 'FETCH_HEAD']);
    return _head(gitDir);
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
    List<String> extraArgs,
  ) async {
    logger.info('ℹ️ Pushing $branch through commit-headless');
    final result = await Process.run(commitHeadlessBinary, [
      'push',
      '-T',
      repoSlug!,
      '--branch',
      branch,
      ...extraArgs,
    ], workingDirectory: gitDir.path);
    if (result.exitCode != 0) {
      throw GitReleaseActionError(
        'commit-headless push of $branch failed: ${result.stderr}',
      );
    }

    // On success it prints only the SHA of the last commit it created.
    final pushedSha = (result.stdout as String).trim().split('\n').last.trim();
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
