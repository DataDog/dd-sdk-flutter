// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:git/git.dart';

/// The commit a release tag points at, or null if the tag doesn't exist.
///
/// Deliberately a **lookup by exact name**, not a search. Which versions
/// exist is pub.dev's question (see `published_versions.dart`); git is only
/// asked where a version already known to exist actually landed.
///
/// That split is what keeps this file free of heuristics. Searching tags for
/// "what did we last ship on this line" means guessing from tag names --
/// scoping by major/minor, filtering to stable versions, ordering candidates,
/// testing ancestry -- and none of those guesses can be made reliable here,
/// because release tags live on `release/...` branches that are never merged
/// back. An ancestry test, for instance, rejects every real release: none of
/// them is reachable from `develop`.
///
/// Returns null rather than throwing: pub.dev can legitimately know a version
/// git can't locate (a release published before its tag was pushed, or whose
/// tag was never pushed at all -- two of `datadog_flutter_plugin`'s 65
/// published versions are in that state). The caller reports the fallback it
/// took; see `release_plan.dart`.
Future<String?> tagSha(GitDir gitDir, String tagName) async {
  final result = await gitDir.runCommand([
    'rev-list',
    '-n',
    '1',
    tagName,
  ], throwOnError: false);

  if (result.exitCode != 0) return null;
  final sha = (result.stdout as String).trim();
  return sha.isEmpty ? null : sha;
}

/// [relativePath]'s content as it existed at the commit tagged [tagName], or
/// null if the tag can't be resolved (see [tagSha]) or the file didn't
/// exist at that commit.
Future<String?> fileContentAtTag(
  GitDir gitDir,
  String tagName,
  String relativePath,
) async {
  final sha = await tagSha(gitDir, tagName);
  if (sha == null) return null;

  final result = await gitDir.runCommand([
    'show',
    '$sha:$relativePath',
  ], throwOnError: false);

  return result.exitCode == 0 ? result.stdout as String : null;
}

/// Full commit messages (subject + body/footers) touching [pathspec], from
/// just after [sinceSha] through HEAD. A null [sinceSha] walks the entire
/// history of [pathspec] -- the "since inception" case for a package that has
/// never been published.
Future<List<String>> commitMessagesSince(
  GitDir gitDir, {
  required String pathspec,
  String? sinceSha,
}) async {
  final range = sinceSha != null ? '$sinceSha..HEAD' : 'HEAD';
  final result = await gitDir.runCommand([
    '--no-pager',
    'log',
    range,
    '--pretty=format:%B|||END|||',
    '--',
    pathspec,
  ]);

  return (result.stdout as String)
      .split('|||END|||')
      .map((m) => m.trim())
      .where((m) => m.isNotEmpty)
      .toList();
}
