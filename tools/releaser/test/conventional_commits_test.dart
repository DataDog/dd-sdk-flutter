// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:test/test.dart';

import 'package:releaser/conventional_commits.dart';
import 'package:releaser/version_updater.dart';

/// Shorthand matching the old `classifyCommitBump` free function's
/// behavior, for tests that just want a message's bump type.
VersionBumpType? _bumpOf(String commitMessage) =>
    ConventionalCommit.parse(commitMessage)?.bumpType;

/// Parses each message, dropping any that don't parse -- for feeding
/// [aggregateBumpLevel], which now operates on [ConventionalCommit]s.
List<ConventionalCommit> _parseAll(List<String> messages) =>
    messages.map(ConventionalCommit.parse).nonNulls.toList();

void main() {
  group('ConventionalCommit.parse -- bumpType', () {
    test('feat: is a minor bump', () {
      expect(
        _bumpOf('feat: add frustration signal tracking'),
        VersionBumpType.minor,
      );
    });

    test('fix: and perf: are patch bumps', () {
      expect(
        _bumpOf('fix: correct crash on session init'),
        VersionBumpType.patch,
      );
      expect(_bumpOf('perf: reduce startup overhead'), VersionBumpType.patch);
    });

    test('a ! after the type/scope is a major bump regardless of type', () {
      expect(
        _bumpOf('feat!: remove deprecated trackEvent API'),
        VersionBumpType.major,
      );
      expect(
        _bumpOf('fix(ios)!: change method signature'),
        VersionBumpType.major,
      );
    });

    test('a BREAKING CHANGE footer is a major bump', () {
      final message =
          'feat: add new config option\n\n'
          'BREAKING CHANGE: the old option is removed';
      expect(_bumpOf(message), VersionBumpType.major);
    });

    test('chore/docs/test do not carry semver weight on their own', () {
      expect(_bumpOf('chore: bump dependencies'), isNull);
      expect(_bumpOf('docs: fix typo in README'), isNull);
      expect(_bumpOf('test: add missing coverage'), isNull);
    });

    test('a non-conventional-commit message fails to parse entirely', () {
      expect(
        ConventionalCommit.parse('Merge pull request #123 from foo/bar'),
        isNull,
      );
    });
  });

  group('aggregateBumpLevel', () {
    test('picks the highest severity across all commits', () {
      final bump = aggregateBumpLevel(
        _parseAll([
          'fix: correct crash',
          'chore: cleanup',
          'feat: add a thing',
        ]),
      );
      expect(bump, VersionBumpType.minor);
    });

    test('a single breaking commit outranks everything else', () {
      final bump = aggregateBumpLevel(
        _parseAll([
          'fix: correct crash',
          'feat!: remove old API',
          'feat: add a thing',
        ]),
      );
      expect(bump, VersionBumpType.major);
    });

    test('returns null when nothing carries semver weight', () {
      final bump = aggregateBumpLevel(
        _parseAll(['chore: cleanup', 'docs: fix typo']),
      );
      expect(bump, isNull);
    });

    test('returns null for an empty list', () {
      expect(aggregateBumpLevel(<ConventionalCommit>[]), isNull);
    });
  });
}
