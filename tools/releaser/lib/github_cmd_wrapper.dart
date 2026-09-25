// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';

import 'pr_resolution.dart';
import 'process_helper.dart';

part 'github_cmd_wrapper.g.dart';

@JsonSerializable()
class GHRelease {
  final bool isLatest;
  final String name;
  final String tagName;

  GHRelease({
    required this.isLatest,
    required this.name,
    required this.tagName,
  });

  factory GHRelease.fromJson(Map<String, dynamic> json) =>
      _$GHReleaseFromJson(json);
  Map<String, dynamic> toJson() => _$GHReleaseToJson(this);
}

/// Wraps the `gh` command line tool for performing operations with Github
///
/// Read-only lookups are cached for the life of the instance -- see
/// [fetchReleases] and [getCommitSha]. Construct one per run (every call site
/// already does) and the cache lifetime takes care of itself.
class GithubCommandWrapper {
  final String cwd;

  /// Keyed by repo slug for [fetchReleases], and by `slug@ref` for
  /// [getCommitSha]. Futures rather than results, so concurrent askers share
  /// one in-flight call instead of racing to start their own.
  final _releasesByRepo = <String, Future<List<GHRelease>>>{};
  final _shaByRef = <String, Future<String>>{};

  GithubCommandWrapper(this.cwd);

  Future<bool> checkAuth(Logger logger) async {
    final exitCode = await runProcess(
      'gh',
      ['auth', 'status'],
      workingDirectory: cwd,
      stdout: (line) => logger.info(line),
      stderr: (line) => logger.shout(line),
    );

    return exitCode == 0;
  }

  /// Every release of [repoSlug], fetched once per instance.
  ///
  /// Both [getLatestRelease] and [getReleaseByTagName] go through here, and
  /// each is asked once per package being planned -- "what is the latest
  /// dd-sdk-ios release" has the same answer for all six members of a
  /// federated group, so without this an `--include-federated` run makes a
  /// dozen identical `gh release list` calls.
  ///
  /// A failed lookup stays failed for the life of the instance; nothing here
  /// retries, and a run that can't reach GitHub has no path to succeeding.
  Future<List<GHRelease>> fetchReleases(Logger logger, String repoSlug) =>
      _releasesByRepo.putIfAbsent(
        repoSlug,
        () => _fetchReleases(logger, repoSlug),
      );

  Future<List<GHRelease>> _fetchReleases(Logger logger, String repoSlug) async {
    final buffer = StringBuffer();
    final exitCode = await runProcess(
      'gh',
      [
        'release',
        'list',
        '--repo',
        repoSlug,
        // Without an explicit limit, `gh release list` only returns the 30
        // most recent releases -- silently hiding an older-but-still-valid
        // IOS_SDK_VERSION/ANDROID_SDK_VERSION override, and any repo with
        // more than 30 releases risks losing its "isLatest" entry from the
        // page entirely.
        '--limit',
        '1000',
        '--json',
        'name,isLatest,tagName',
      ],
      workingDirectory: cwd,
      stdout: (line) => buffer.write(line),
      stderr: (line) => logger.shout(line),
    );

    if (exitCode != 0) {
      throw Exception('gh returned exit code $exitCode.');
    }

    final json = jsonDecode(buffer.toString()) as List;
    final releases = json.map((e) => GHRelease.fromJson(e)).toList();
    return releases;
  }

  Future<GHRelease> getLatestRelease(Logger logger, String repoSlug) async {
    final releases = await fetchReleases(logger, repoSlug);
    final latest = releases.firstWhereOrNull((e) => e.isLatest);
    if (latest == null) {
      throw StateError(
        'No release of $repoSlug is marked "latest" (fetched '
        '${releases.length} release(s)).',
      );
    }
    return latest;
  }

  Future<GHRelease?> getReleaseByTagName(
    Logger logger,
    String repoSlug,
    String tagName,
  ) async {
    final releases = await fetchReleases(logger, repoSlug);
    return releases.firstWhereOrNull((e) => e.tagName == tagName);
  }

  /// Resolves [ref] (a tag or branch name) to the full commit SHA it
  /// currently points to, for pinning native SDKs whose config has no
  /// dedicated "verify this tag against this commit" field (CMake's
  /// `FetchContent_Declare`, notably) -- the SHA is what's actually pinned.
  ///
  /// Cached per `slug@ref` for the life of the instance, like
  /// [fetchReleases]: every desktop package resolving the same dd-sdk-cpp
  /// tag should cost one call, not one each.
  Future<String> getCommitSha(Logger logger, String repoSlug, String ref) =>
      _shaByRef.putIfAbsent(
        '$repoSlug@$ref',
        () => _getCommitSha(logger, repoSlug, ref),
      );

  Future<String> _getCommitSha(
    Logger logger,
    String repoSlug,
    String ref,
  ) async {
    final buffer = StringBuffer();
    final exitCode = await runProcess(
      'gh',
      ['api', 'repos/$repoSlug/commits/$ref', '--jq', '.sha'],
      workingDirectory: cwd,
      stdout: (line) => buffer.write(line),
      stderr: (line) => logger.shout(line),
    );

    if (exitCode != 0) {
      throw Exception('gh returned exit code $exitCode.');
    }

    return buffer.toString().trim();
  }

  /// Raw content of [path] in [repoSlug] at its default branch HEAD -- via
  /// `gh api`'s raw-media-type override, which returns the file's bytes
  /// directly instead of the JSON+base64 envelope the endpoint returns by
  /// default. `native_sdk_changelog.dart` uses this to fetch `CHANGELOG.md`.
  Future<String> fetchFileContent(
    Logger logger,
    String repoSlug,
    String path,
  ) async {
    final buffer = StringBuffer();
    final exitCode = await runProcess(
      'gh',
      [
        'api',
        '-H',
        'Accept: application/vnd.github.raw',
        'repos/$repoSlug/contents/$path',
      ],
      workingDirectory: cwd,
      stdout: (line) => buffer.writeln(line),
      stderr: (line) => logger.shout(line),
    );

    if (exitCode != 0) {
      throw Exception('gh returned exit code $exitCode.');
    }

    return buffer.toString();
  }

  /// This repo's `owner/name` slug, via `gh repo view` -- so the release PR
  /// body can link straight to a package's `CHANGELOG.md` on the
  /// release-prep branch (see `release_pr.dart`) without hardcoding the
  /// slug or trying to derive it from `git remote` output.
  Future<String> repoSlug(Logger logger) async {
    final buffer = StringBuffer();
    final exitCode = await runProcess(
      'gh',
      ['repo', 'view', '--json', 'nameWithOwner'],
      workingDirectory: cwd,
      stdout: (line) => buffer.write(line),
      stderr: (line) => logger.shout(line),
    );

    if (exitCode != 0) {
      throw Exception('gh returned exit code $exitCode.');
    }

    final json = jsonDecode(buffer.toString()) as Map<String, dynamic>;
    return json['nameWithOwner'] as String;
  }

  /// `gh pr view {number}`'s title + body -- the richer LLM input
  /// `llm/changelog.dart`'s changelog pass needs, beyond what
  /// [searchMergedPrBySha]/the squash-merge suffix already gives
  /// [ResolvedPr] for free.
  Future<PrDetails> fetchPrDetails(Logger logger, int number) async {
    final buffer = StringBuffer();
    final exitCode = await runProcess(
      'gh',
      ['pr', 'view', '$number', '--json', 'number,title,body'],
      workingDirectory: cwd,
      stdout: (line) => buffer.write(line),
      stderr: (line) => logger.shout(line),
    );

    if (exitCode != 0) {
      throw Exception('gh returned exit code $exitCode.');
    }

    final json = jsonDecode(buffer.toString()) as Map<String, dynamic>;
    return PrDetails(
      number: json['number'] as int,
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
    );
  }

  /// `gh pr list --search "{sha}"` -- the fallback `pr_resolution.dart` uses
  /// for a commit that didn't land via a squash merge (no `(#N)` suffix to
  /// parse locally). Merged PRs only; the newest match if somehow more than
  /// one comes back.
  Future<ResolvedPr?> searchMergedPrBySha(Logger logger, String sha) async {
    final buffer = StringBuffer();
    final exitCode = await runProcess(
      'gh',
      [
        'pr',
        'list',
        '--search',
        sha,
        '--state',
        'merged',
        '--json',
        'number,title',
        '--limit',
        '1',
      ],
      workingDirectory: cwd,
      stdout: (line) => buffer.write(line),
      stderr: (line) => logger.shout(line),
    );

    if (exitCode != 0) {
      throw Exception('gh returned exit code $exitCode.');
    }

    final json = jsonDecode(buffer.toString()) as List;
    if (json.isEmpty) return null;
    final entry = json.first as Map<String, dynamic>;
    return ResolvedPr(
      number: entry['number'] as int,
      title: entry['title'] as String,
    );
  }

  /// `gh pr create` for a release-prep branch -- returns the created PR's
  /// URL. [body] is passed via a temp file (like
  /// `CommitChangesCommand`'s `commitBody`) since a release PR body is
  /// long-form markdown (version table, changelog diff, native SDK
  /// deltas), not something safe to hand through a single CLI argument.
  Future<String> createPullRequest(
    Logger logger, {
    required String base,
    required String head,
    required String title,
    required String body,
  }) async {
    final tempFile = await File(
      '${Directory.systemTemp.path}/dart_releaser_pr_body_'
      '${DateTime.now().microsecondsSinceEpoch}.tmp',
    ).create();
    await tempFile.writeAsString(body);

    final buffer = StringBuffer();
    try {
      final exitCode = await runProcess(
        'gh',
        [
          'pr',
          'create',
          '--base',
          base,
          '--head',
          head,
          '--title',
          title,
          '--body-file',
          tempFile.path,
        ],
        workingDirectory: cwd,
        stdout: (line) => buffer.write(line),
        stderr: (line) => logger.shout(line),
      );

      if (exitCode != 0) {
        throw Exception('gh returned exit code $exitCode.');
      }
    } finally {
      await tempFile.delete();
    }

    return buffer.toString().trim();
  }

  /// `gh release create` for a package that just published. [latest]
  /// controls `--latest`/`--latest=false` -- a patch on an old minor line,
  /// or a pre-release, should never claim "latest" over a newer mainline
  /// release. [prerelease] adds `--prerelease`. [notes] goes via a temp
  /// file, like [createPullRequest]'s body -- a changelog section is
  /// long-form markdown, not safe as a single CLI argument.
  Future<void> createRelease(
    Logger logger, {
    required String tag,
    required String title,
    required String notes,
    required bool latest,
    required bool prerelease,
  }) async {
    final tempFile = await File(
      '${Directory.systemTemp.path}/dart_releaser_release_notes_'
      '${DateTime.now().microsecondsSinceEpoch}.tmp',
    ).create();
    await tempFile.writeAsString(notes);

    try {
      final exitCode = await runProcess(
        'gh',
        [
          'release',
          'create',
          tag,
          '--title',
          title,
          '--notes-file',
          tempFile.path,
          latest ? '--latest' : '--latest=false',
          if (prerelease) '--prerelease',
        ],
        workingDirectory: cwd,
        stdout: (line) => logger.info(line),
        stderr: (line) => logger.shout(line),
      );

      if (exitCode != 0) {
        throw Exception('gh returned exit code $exitCode.');
      }
    } finally {
      await tempFile.delete();
    }
  }

  /// Whether [context]'s status is `success` for [sha] -- the authenticity
  /// check `publish_release.dart` runs before doing anything else, since a
  /// `release-trigger/*` tag isn't branch-protected and this is what
  /// actually proves GitLab's pipeline passed for this exact commit.
  ///
  /// `per_page=100` is explicit rather than relying on `gh api --paginate`:
  /// that flag only auto-follows `Link`-header pagination for endpoints
  /// that return a JSON array at the top level, and this one returns a
  /// single object with a nested `statuses` array, so `--paginate` would
  /// not merge multiple pages of it anyway. 100 (the API's max) comfortably
  /// covers this repo's ~20-30 status contexts in one page.
  Future<bool> commitStatusIsSuccess(
    Logger logger,
    String repoSlug,
    String sha,
    String context,
  ) async {
    final buffer = StringBuffer();
    final exitCode = await runProcess(
      'gh',
      [
        'api',
        'repos/$repoSlug/commits/$sha/status',
        '-f',
        'per_page=100',
      ],
      workingDirectory: cwd,
      stdout: (line) => buffer.writeln(line),
      stderr: (line) => logger.shout(line),
    );

    if (exitCode != 0) {
      throw Exception('gh returned exit code $exitCode.');
    }

    final json = jsonDecode(buffer.toString()) as Map<String, dynamic>;
    return commitStatusStateIsSuccess(json, context);
  }

  /// The most recent `gh run list` entry for [workflow] triggered by
  /// [tagRef], or `null` if none exists yet. `status` is
  /// `'completed'`/`'in_progress'`/`'queued'`; `conclusion` is only
  /// meaningful once `status == 'completed'`. Used to poll a
  /// `publish-package.yml` run to a terminal state before moving on to the
  /// next package, which is what preserves topological order across a
  /// federated group's packages.
  Future<WorkflowRunState?> latestWorkflowRun(
    Logger logger,
    String repoSlug,
    String workflow,
    String tagRef,
  ) async {
    final buffer = StringBuffer();
    final exitCode = await runProcess(
      'gh',
      [
        'run',
        'list',
        '--repo',
        repoSlug,
        '--workflow',
        workflow,
        '--json',
        'headBranch,status,conclusion,createdAt,url',
        '--limit',
        '20',
      ],
      workingDirectory: cwd,
      stdout: (line) => buffer.write(line),
      stderr: (line) => logger.shout(line),
    );

    if (exitCode != 0) {
      throw Exception('gh returned exit code $exitCode.');
    }

    final json = jsonDecode(buffer.toString()) as List;
    return selectLatestWorkflowRun(json, tagRef);
  }

  /// The commit SHA [tagName] currently points to on [remote], or `null` if
  /// the tag doesn't exist there. Used before pushing a package's version
  /// tag so a re-run after a partial failure can tell "already pushed,
  /// nothing to do" apart from "would overwrite a different commit" --
  /// `git push` alone refuses an already-existing tag either way, which
  /// makes every retry after a partial failure a manual-cleanup incident.
  Future<String?> remoteTagCommitSha(
    Logger logger,
    String tagName, {
    String remote = 'origin',
  }) async {
    final buffer = StringBuffer();
    final exitCode = await runProcess(
      'git',
      ['ls-remote', remote, 'refs/tags/$tagName^{}'],
      workingDirectory: cwd,
      stdout: (line) => buffer.writeln(line),
      stderr: (line) => logger.shout(line),
    );

    if (exitCode != 0) {
      throw Exception('git ls-remote returned exit code $exitCode.');
    }

    final line = buffer.toString().trim();
    if (line.isEmpty) return null;
    // `<sha>\trefs/tags/<name>^{}` -- take the SHA.
    return line.split(RegExp(r'\s+')).first;
  }

  /// The number of an open PR from [head] into [base], or `null` if none
  /// exists. Used before opening the commit-A backport PR so a re-run
  /// after a partial failure (tag/PR already created, something later
  /// failed) doesn't hit `gh pr create`'s "a pull request already exists"
  /// error.
  Future<int?> findOpenPullRequest(
    Logger logger, {
    required String head,
    required String base,
  }) async {
    final buffer = StringBuffer();
    final exitCode = await runProcess(
      'gh',
      [
        'pr',
        'list',
        '--head',
        head,
        '--base',
        base,
        '--state',
        'open',
        '--json',
        'number',
        '--limit',
        '1',
      ],
      workingDirectory: cwd,
      stdout: (line) => buffer.write(line),
      stderr: (line) => logger.shout(line),
    );

    if (exitCode != 0) {
      throw Exception('gh returned exit code $exitCode.');
    }

    final json = jsonDecode(buffer.toString()) as List;
    if (json.isEmpty) return null;
    return (json.first as Map<String, dynamic>)['number'] as int;
  }

  /// `gh pr merge {number} --auto --merge` -- queues [prNumber] for
  /// GitHub's native auto-merge using the `merge` strategy specifically,
  /// never squash/rebase, since Phase 2's backport PR needs commit A's
  /// original SHA to land on the dev-line branch, not a re-authored
  /// duplicate. Still subject to the branch's required review/status
  /// checks -- this only queues it, a human still has to approve.
  Future<void> enableAutoMergeWithMergeCommit(
    Logger logger,
    int prNumber,
  ) async {
    final exitCode = await runProcess(
      'gh',
      ['pr', 'merge', '$prNumber', '--auto', '--merge'],
      workingDirectory: cwd,
      stdout: (line) => logger.info(line),
      stderr: (line) => logger.shout(line),
    );

    if (exitCode != 0) {
      throw Exception('gh returned exit code $exitCode.');
    }
  }
}

/// A `publish-package.yml` run's state, as read from `gh run list`. See
/// [GithubCommandWrapper.latestWorkflowRun].
class WorkflowRunState {
  final String status;
  final String? conclusion;
  final String url;

  WorkflowRunState({
    required this.status,
    required this.conclusion,
    required this.url,
  });

  bool get isComplete => status == 'completed';
  bool get succeeded => isComplete && conclusion == 'success';
}

/// Pulled out of [GithubCommandWrapper.commitStatusIsSuccess] so it's
/// directly testable against a fabricated response, without a live `gh`
/// call. [statusResponse] is the decoded JSON body of `GET
/// /repos/{repo}/commits/{sha}/status`.
///
/// Takes the *first* entry in `.statuses` matching [context] rather than
/// checking whether every entry matching it says `success` -- the API
/// returns entries newest-first, and a context can legitimately appear
/// more than once if it was posted multiple times (e.g. a retried GitLab
/// job); only the newest posting for that context is the current state.
bool commitStatusStateIsSuccess(
  Map<String, dynamic> statusResponse,
  String context,
) {
  final statuses = (statusResponse['statuses'] as List?) ?? const [];
  for (final entry in statuses) {
    final map = entry as Map<String, dynamic>;
    if (map['context'] == context) {
      return map['state'] == 'success';
    }
  }
  return false;
}

/// Pulled out of [GithubCommandWrapper.latestWorkflowRun] so it's directly
/// testable against a fabricated response, without a live `gh` call.
/// [runs] is the decoded JSON array from `gh run list --json
/// headBranch,status,conclusion,createdAt,url`.
WorkflowRunState? selectLatestWorkflowRun(List<dynamic> runs, String tagRef) {
  final matches =
      runs.cast<Map<String, dynamic>>().where(
        (e) => e['headBranch'] == tagRef,
      ).toList()
        ..sort(
          (a, b) =>
              (b['createdAt'] as String).compareTo(a['createdAt'] as String),
        );
  if (matches.isEmpty) return null;

  final entry = matches.first;
  return WorkflowRunState(
    status: entry['status'] as String,
    conclusion: entry['conclusion'] as String?,
    url: entry['url'] as String,
  );
}
