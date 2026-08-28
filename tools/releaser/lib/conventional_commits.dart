// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'version_bump.dart';

/// A parsed conventional commit: header (`type(scope)!: description`) plus
/// the footers other tooling in this package cares about (a `BREAKING
/// CHANGE:` footer, and `refs:` lines referencing GitHub issues).
class ConventionalCommit {
  final String type;
  final String? scope;

  /// Whether the header itself carries a `!` breaking marker, on either side
  /// of the scope -- see [_headerPattern].
  final bool hasBreakingMarker;
  final String description;

  /// Whether a `BREAKING CHANGE:`/`BREAKING-CHANGE:` footer is present,
  /// independent of [hasBreakingMarker] -- either one marks the commit
  /// breaking, see [isBreaking].
  final bool hasBreakingFooter;

  /// Raw reference tokens from `refs:` footer lines (e.g. `refs: #123,
  /// RUM-456` -> `['#123', 'RUM-456']`) -- a GitHub issue number, a JIRA
  /// ticket, or anything else a `refs:` footer might carry. Not filtered
  /// or interpreted here; a consumer that only wants GitHub issue links
  /// (like `generate_changelog.dart`) picks those out itself.
  final List<String> refs;

  ConventionalCommit({
    required this.type,
    required this.scope,
    required this.hasBreakingMarker,
    required this.description,
    required this.hasBreakingFooter,
    required this.refs,
  });

  bool get isBreaking => hasBreakingMarker || hasBreakingFooter;

  /// The semver bump this commit implies on its own: major if breaking
  /// (marker or footer), minor for `feat`, patch for `fix`/`perf`, or null
  /// for a type that doesn't carry semver weight by itself (`chore:`,
  /// `docs:`, `test:`, etc.) and isn't marked breaking.
  VersionBumpType? get bumpType {
    if (isBreaking) return VersionBumpType.major;

    switch (type) {
      case 'feat':
        return VersionBumpType.minor;
      case 'fix':
      case 'perf':
        return VersionBumpType.patch;
      default:
        return null;
    }
  }

  /// `type(scope)!: description`, with the `!` accepted on either side of the
  /// scope.
  ///
  /// The convention puts it after -- `feat(web)!:` -- but `feat!(web):` gets
  /// written in practice, and this repo's history already contains one. The
  /// cost of not accepting it is badly asymmetric: an unparsed header is
  /// dropped entirely, so the one shape most likely to be typo'd is also the
  /// one whose loss matters most. A commit that means "breaking" would
  /// silently contribute nothing, and a release that should be major comes
  /// out minor.
  static final _headerPattern = RegExp(
    r'^(?<type>\w+)(?<earlyBreaking>!)?(\((?<scope>[^)]*)\))?'
    r'(?<breaking>!)?:\s*(?<rest>.*)',
  );
  static final _breakingFooterPattern = RegExp(
    r'^BREAKING[ -]CHANGE:',
    multiLine: true,
  );

  /// Parses a full commit message (subject line plus body/footers) into
  /// its conventional-commit parts, or returns null if the subject line
  /// doesn't match the convention at all.
  static ConventionalCommit? parse(String commitMessage) {
    final lines = commitMessage.split('\n');
    final match = _headerPattern.firstMatch(lines.first);
    if (match == null) return null;

    final refs = [
      for (final refLine in lines.where((l) => l.startsWith('refs:')))
        for (final token
            in refLine.substring('refs:'.length).split(RegExp(r'[,\s]+')))
          if (token.isNotEmpty) token,
    ];

    return ConventionalCommit(
      type: match.namedGroup('type')!,
      scope: match.namedGroup('scope'),
      hasBreakingMarker:
          match.namedGroup('breaking') == '!' ||
          match.namedGroup('earlyBreaking') == '!',
      description: match.namedGroup('rest')!,
      hasBreakingFooter: _breakingFooterPattern.hasMatch(commitMessage),
      refs: refs,
    );
  }
}

/// The highest-severity bump implied by [commits] (major > minor > patch),
/// or null if none of them carry semver weight.
VersionBumpType? aggregateBumpLevel(Iterable<ConventionalCommit> commits) {
  VersionBumpType? highest;
  for (final commit in commits) {
    final bump = commit.bumpType;
    if (bump == null) continue;
    if (highest == null || bump.severity > highest.severity) {
      highest = bump;
    }
  }
  return highest;
}
