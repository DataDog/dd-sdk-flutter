// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:logging/logging.dart';

import 'github_cmd_wrapper.dart';
import 'native_sdk.dart';

/// One version's worth of entries from a native SDK's `CHANGELOG.md`.
class ChangelogSection {
  final String version;
  final List<String> entries;

  const ChangelogSection({required this.version, required this.entries});
}

/// A changelog heading's bare semver, across all three native SDKs' real
/// formats: `# 3.16.0 / 19-08-2026` (iOS), `# 3.12.1 / 2026-07-16`
/// (Android), `## 0.7.0` (C++). All start with `#`/`##` then a bare semver
/// -- nothing else about the three formats is shared, but that's enough.
/// `#{1,2}` also excludes C++'s `### Breaking Changes`/`### Features`
/// sub-headings, which aren't version boundaries.
final _headingPattern = RegExp(r'^#{1,2}\s*(?<version>\d+\.\d+\.\d+)\b');

/// Parses raw `CHANGELOG.md` content into ordered sections, newest first
/// (the file's own order). Content before the first version heading (an
/// `# Unreleased` section, if present) is dropped -- it isn't a resolved
/// version, so it can never be a diff boundary. A sub-heading like C++'s
/// `### Breaking Changes` doesn't start a new section; its line is kept as
/// a plain entry, since it's still meaningful content for a human or an
/// LLM reading the section.
List<ChangelogSection> parseChangelog(String content) {
  final sections = <ChangelogSection>[];
  String? version;
  var entries = <String>[];

  void flush() {
    if (version != null) {
      sections.add(ChangelogSection(version: version, entries: entries));
    }
  }

  for (final line in content.split('\n')) {
    final match = _headingPattern.firstMatch(line);
    if (match != null) {
      flush();
      version = match.namedGroup('version');
      entries = [];
    } else if (version != null && line.trim().isNotEmpty) {
      entries.add(line.trim());
    }
  }
  flush();

  return sections;
}

/// The sections strictly newer than [fromVersion] down through [toVersion]
/// (inclusive), newest first -- what actually changed for this bump.
///
/// Null if either version isn't a heading anywhere in [sections]: there's
/// no reliable boundary to slice at, and unlike a git tag lookup there's no
/// bound on how far back an unmatched version's changelog goes -- showing
/// "everything" risks dumping years of another repo's history into preview
/// output. The caller skips display with a warning instead.
List<ChangelogSection>? sectionsBetween(
  List<ChangelogSection> sections, {
  required String fromVersion,
  required String toVersion,
}) {
  final fromIndex = sections.indexWhere((s) => s.version == fromVersion);
  final toIndex = sections.indexWhere((s) => s.version == toVersion);
  if (fromIndex == -1 || toIndex == -1 || toIndex > fromIndex) return null;

  return sections.sublist(toIndex, fromIndex);
}

/// Fetches [repoSlug]'s `CHANGELOG.md` and parses it -- the sole network
/// call this module needs, injected (see [githubChangelogFetcher]) so
/// [resolveNativeSdkChangelog]'s parsing/slicing logic stays testable
/// without shelling out to `gh`.
typedef ChangelogFetcher =
    Future<List<ChangelogSection>> Function(String repoSlug);

/// A [ChangelogFetcher] backed by a real `gh api` call against [repoSlug]'s
/// default branch -- not a specific tag, since `CHANGELOG.md` is append-only
/// in practice and this way there's exactly one fetch per SDK regardless of
/// which version range is being displayed.
ChangelogFetcher githubChangelogFetcher(
  Logger logger,
  GithubCommandWrapper github,
) {
  return (repoSlug) async {
    final content = await github.fetchFileContent(
      logger,
      repoSlug,
      'CHANGELOG.md',
    );
    return parseChangelog(content);
  };
}

/// What changed for one native SDK bump -- exactly one of [sections] or
/// [warning] is set. [sections] can be empty (current and target are the
/// same version once normalized, or genuinely adjacent with nothing
/// between them); [warning] means the display should be skipped entirely,
/// not shown with an empty range.
class NativeSdkChangelogResult {
  final List<ChangelogSection>? sections;
  final String? warning;

  const NativeSdkChangelogResult({this.sections, this.warning});
}

/// Resolves what changed in [sdk] between [currentDeclaration] (as read
/// from the working tree/last release, in whatever format that SDK's
/// dependency file declares it) and [targetVersion] (this run's resolved
/// pin) -- see [NativeSdkChangelogResult].
Future<NativeSdkChangelogResult> resolveNativeSdkChangelog(
  NativeSdk sdk, {
  required String? currentDeclaration,
  required String targetVersion,
  required ChangelogFetcher fetchChangelog,
}) async {
  final fromVersion = normalizeVersion(currentDeclaration);
  if (fromVersion == null) {
    return NativeSdkChangelogResult(
      warning:
          '${sdk.name}: no resolvable current version ("$currentDeclaration") '
          'to diff from -- skipping changelog.',
    );
  }

  final sections = await fetchChangelog(sdk.repoSlug);
  final sliced = sectionsBetween(
    sections,
    fromVersion: fromVersion,
    toVersion: targetVersion,
  );
  if (sliced == null) {
    return NativeSdkChangelogResult(
      warning:
          '${sdk.name}: could not find $fromVersion and/or $targetVersion '
          'in CHANGELOG.md -- skipping changelog.',
    );
  }

  return NativeSdkChangelogResult(sections: sliced);
}

/// A stable, browsable link to [sdk]'s full `CHANGELOG.md` -- `HEAD` lets
/// GitHub resolve to whatever the repo's actual default branch is, without
/// hardcoding it here.
String nativeSdkChangelogUrl(NativeSdk sdk) =>
    'https://github.com/${sdk.repoSlug}/blob/HEAD/CHANGELOG.md';
