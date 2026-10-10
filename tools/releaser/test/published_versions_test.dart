// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:releaser/published_versions.dart';
import 'package:test/test.dart';
import 'package:version/version.dart';

PublishedVersions of(List<String> versions) =>
    PublishedVersions(versions.map(Version.parse).toList());

void main() {
  group('queries', () {
    // Shaped like datadog_flutter_plugin's real history: an old pre-release
    // line, several stable lines, and a live pre-release line on top.
    final history = of([
      '1.0.0-rc.1',
      '1.0.0',
      '3.1.2',
      '3.1.3',
      '3.5.0',
      '4.0.0-beta.1',
      '4.0.0-beta.2',
    ]);

    test('latest is the newest release of any kind', () {
      // What a commit range and an eligibility check want -- "when did we
      // last ship anything" -- so an untouched package on a pre-release line
      // doesn't re-walk its whole history.
      expect(history.latest, Version.parse('4.0.0-beta.2'));
    });

    test('latestStable skips the live pre-release line', () {
      expect(history.latestStable, Version.parse('3.5.0'));
    });

    test('latestOn restricts to one release line', () {
      expect(history.latestOn(3, 1), Version.parse('3.1.3'));
      expect(history.latestOn(9, 9), isNull);
    });

    test('prereleasesAt finds the counter for a target', () {
      expect(history.prereleasesAt(Version.parse('4.0.0')), [
        Version.parse('4.0.0-beta.1'),
        Version.parse('4.0.0-beta.2'),
      ]);
    });

    test("prereleasesAt ignores the target's own pre-release suffix", () {
      // A pubspec sitting at 4.0.0-beta.1 mid-line still targets 4.0.0.
      expect(
        history.prereleasesAt(Version.parse('4.0.0-beta.1')),
        hasLength(2),
      );
    });

    test('hasStableAt detects an already-shipped target', () {
      expect(history.hasStableAt(Version.parse('1.0.0')), isTrue);
      expect(history.hasStableAt(Version.parse('4.0.0')), isFalse);
    });

    test('an unpublished package answers everything with null/empty', () {
      expect(PublishedVersions.never.isEmpty, isTrue);
      expect(PublishedVersions.never.latest, isNull);
      expect(PublishedVersions.never.latestStable, isNull);
      expect(PublishedVersions.never.latestOn(1, 0), isNull);
    });

    test('input order does not matter', () {
      expect(of(['3.5.0', '1.0.0', '3.1.3']).latest, Version.parse('3.5.0'));
    });
  });

  group('parsePubDevVersions', () {
    test('reads the version list from a pub.dev payload', () {
      final body =
          jsonDecode('''
{"name":"datadog_dio","latest":{"version":"2.3.0"},
 "versions":[{"version":"2.2.0"},{"version":"2.3.0-beta.1"},{"version":"2.3.0"}]}
''')
              as Map<String, dynamic>;

      expect(
        PublishedVersions(parsePubDevVersions(body)).latest,
        Version.parse('2.3.0'),
      );
      expect(parsePubDevVersions(body), hasLength(3));
    });

    test('skips an entry that is not valid semver rather than failing', () {
      // pub.dev won't serve one, but a malformed entry must not be able to
      // block a release.
      final body =
          jsonDecode(
                '{"versions":[{"version":"1.0.0"},{"version":"not-a-version"}]}',
              )
              as Map<String, dynamic>;

      expect(parsePubDevVersions(body), [Version.parse('1.0.0')]);
    });

    test('a payload with no versions yields an empty history', () {
      expect(parsePubDevVersions(<String, dynamic>{}), isEmpty);
    });
  });
}
