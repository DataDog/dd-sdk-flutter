// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package_discovery.dart';

/// One package's entry in a [ReleaseManifest] -- what Phase 2 needs to
/// publish, tag, and release it.
class ManifestPackageEntry {
  final String package;
  final String toVersion;
  final bool prerelease;
  final bool isPatch;
  final String relativePath;

  ManifestPackageEntry({
    required this.package,
    required this.toVersion,
    required this.prerelease,
    required this.isPatch,
    required this.relativePath,
  });
}

/// What one `prepare_release.dart` run did, as `publish_release.dart`
/// reconstructs it. A mainline/pre-release run is read from its release PR's
/// body (see [parseVersionsTable]/[parseContentCommit]); a patch run has no
/// PR, so it is read from its own commit message (see
/// [parsePatchVersionSummary]).
class ReleaseManifest {
  /// Commit A's SHA (mainline/pre-release), backported into the dev-line
  /// branch by Phase 2 via `release-content/*`. `null` on a patch run, which
  /// doesn't split its commits, so there is nothing for Phase 2 to backport.
  final String? contentCommit;
  final List<ManifestPackageEntry> packages;

  ReleaseManifest({required this.contentCommit, required this.packages});
}

/// One package's version change as `release_pr.dart` writes it: a `## Versions`
/// table row, or a patch commit message's `versionSummary` line. Carries no
/// path -- [manifestPackagesFor] resolves that.
class ParsedVersionRow {
  final String package;
  final String fromVersion;
  final String toVersion;
  final String bump;

  ParsedVersionRow({
    required this.package,
    required this.fromVersion,
    required this.toVersion,
    required this.bump,
  });
}

// Cells are `[^|]+`, not `\S+` -- the bump column's "first release" fallback
// (`release_pr.dart`'s `versionSummary`/`prBody`) is two words.
final _versionsTableRowPattern = RegExp(
  r'^\|([^|]+)\|([^|]+)\|([^|]+)\|([^|]+)\|$',
);

/// Parses `release_pr.dart`'s `## Versions` table out of a release PR's body.
/// The rows are the `|`-prefixed lines after the heading, minus the first two
/// (the header and the `|---|` separator). Throws on a row that doesn't have
/// four cells, since skipping it would silently drop a package from the
/// release.
List<ParsedVersionRow> parseVersionsTable(String prBody) {
  // GitHub returns CRLF line endings for a body edited in its web UI.
  final lines = prBody.split(RegExp(r'\r?\n'));
  final headingIndex = lines.indexWhere((l) => l.trim() == '## Versions');
  if (headingIndex == -1) return const [];

  var i = headingIndex + 1;
  while (i < lines.length && !lines[i].trimLeft().startsWith('|')) {
    i++;
  }
  i += 2;

  final rows = <ParsedVersionRow>[];
  for (; i < lines.length; i++) {
    final line = lines[i].trim();
    if (!line.startsWith('|')) break;
    final match = _versionsTableRowPattern.firstMatch(line);
    if (match == null) {
      throw StateError(
        'Malformed row in the release PR\'s "## Versions" table: "$line"',
      );
    }
    rows.add(
      ParsedVersionRow(
        package: match.group(1)!.trim(),
        fromVersion: match.group(2)!.trim(),
        toVersion: match.group(3)!.trim(),
        bump: match.group(4)!.trim(),
      ),
    );
  }
  return rows;
}

final _contentCommitPattern = RegExp(r'_Content commit: `([0-9a-f]{40})`_');

/// Parses `release_pr.dart`'s "Content commit: `sha`" line out of a release
/// PR's body. `null` if absent.
String? parseContentCommit(String prBody) =>
    _contentCommitPattern.firstMatch(prBody)?.group(1);

/// Builds the [ManifestPackageEntry] list for [rows] (from either
/// [parseVersionsTable] or [parsePatchVersionSummary]). A row carries no
/// path, so each package's `relativePath` comes from package discovery
/// against [repoRoot] -- the checkout is the tree the release-prep run
/// produced, so discovery finds the same packages it did.
Future<List<ManifestPackageEntry>> manifestPackagesFor(
  List<ParsedVersionRow> rows, {
  required String repoRoot,
  required bool isPatch,
}) async {
  if (rows.isEmpty) return const [];

  final byName = {
    for (final pkg in (await discoverPackages(
      repoRoot,
    )).expand((g) => g.members))
      pkg.name: pkg,
  };

  return [
    for (final row in rows)
      ManifestPackageEntry(
        package: row.package,
        toVersion: row.toVersion,
        prerelease: row.bump == 'prerelease',
        isPatch: isPatch,
        relativePath:
            byName[row.package]?.relativePath ??
            (throw StateError(
              '"${row.package}" was not found by package discovery against '
              'this checkout -- cannot locate its CHANGELOG.md.',
            )),
      ),
  ];
}

/// [manifestPackagesFor] for a release PR body's `## Versions` table.
Future<List<ManifestPackageEntry>> manifestPackagesFromPrBody(
  String prBody, {
  required String repoRoot,
}) => manifestPackagesFor(
  parseVersionsTable(prBody),
  repoRoot: repoRoot,
  isPatch: false,
);

final _versionSummaryLinePattern = RegExp(
  r'^- (\S+): (\S+) -> (\S+) \((.+)\)$',
);

/// Parses the `versionSummary` line out of a patch run's commit message body.
/// A patch run has no PR, so its commit message carries the summary that a
/// mainline/pre-release run puts in the PR's `## Versions` table.
///
/// A patch run is always exactly one package, so this takes the first
/// matching line and ignores the rest. `null` if the message has no such
/// line at all (not a `prepare_release.dart` patch commit).
ParsedVersionRow? parsePatchVersionSummary(String commitMessageBody) {
  for (final line in commitMessageBody.split('\n')) {
    final match = _versionSummaryLinePattern.firstMatch(line.trim());
    if (match == null) continue;
    return ParsedVersionRow(
      package: match.group(1)!,
      fromVersion: match.group(2)!,
      toVersion: match.group(3)!,
      bump: match.group(4)!,
    );
  }
  return null;
}
