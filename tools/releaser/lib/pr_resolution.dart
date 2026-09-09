// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

/// The PR a contributing commit landed through -- see [resolvePr].
class ResolvedPr {
  final int number;
  final String title;

  const ResolvedPr({required this.number, required this.title});

  @override
  String toString() => '#$number $title';
}

/// A PR's full title and body -- richer LLM input than a commit message or
/// [ResolvedPr]'s bare title alone (see `llm/changelog.dart`). Fetched
/// separately from resolution itself: most commits resolve to a PR number
/// for free via the squash-merge suffix, but the LLM changelog pass needs
/// the body too, which only a `gh pr view` call provides (see
/// `GithubCommandWrapper.fetchPrDetails`).
class PrDetails {
  final int number;
  final String title;
  final String body;

  const PrDetails({
    required this.number,
    required this.title,
    required this.body,
  });
}

/// GitHub's squash-merge suffix, appended to the commit subject: `... (#N)`.
final _squashSuffixPattern = RegExp(r'^(?<title>.*)\(#(?<number>\d+)\)\s*$');

/// Strips a trailing squash-merge `(#N)` suffix from [description], for
/// display once the PR number's been pulled out and shown separately.
/// A no-op if there's no suffix to strip.
String stripSquashSuffix(String description) {
  final match = _squashSuffixPattern.firstMatch(description);
  return match == null ? description : match.namedGroup('title')!.trim();
}

/// Resolves the PR [subjectLine] (a commit's parsed description, or the raw
/// subject) landed through.
///
/// Tries the free, network-free path first: GitHub's squash-merge commits
/// append `(#N)` to the subject, and that covers the overwhelming majority
/// of commits into this repo. [searchBySha] (`gh pr list --search
/// "sha:{sha}"`) is the fallback for anything else -- a merge commit, a
/// rebase-and-merge -- and is injected here (see `GithubCommandWrapper
/// .searchMergedPrBySha`) so this stays testable without shelling out to
/// `gh`. Returns null if neither finds a PR -- a direct push with no PR is
/// rare, but real.
Future<ResolvedPr?> resolvePr(
  String sha,
  String subjectLine,
  Future<ResolvedPr?> Function(String sha) searchBySha,
) async {
  final match = _squashSuffixPattern.firstMatch(subjectLine);
  if (match != null) {
    return ResolvedPr(
      number: int.parse(match.namedGroup('number')!),
      title: match.namedGroup('title')!.trim(),
    );
  }

  return searchBySha(sha);
}
