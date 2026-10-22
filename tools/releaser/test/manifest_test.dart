// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:test/test.dart';

import 'package:releaser/manifest.dart';

import 'support/fixture_repo.dart';

void main() {
  group('parseContentCommit', () {
    test('extracts the labeled sha', () {
      final sha = 'a'.padRight(40, 'a');
      final body = 'intro text\n\n## Versions\n\n_Content commit: `$sha`_\n';
      expect(parseContentCommit(body), sha);
    });

    test('null when absent (e.g. a patch release has no PR at all)', () {
      expect(parseContentCommit('## Versions\n\nno such line here'), isNull);
    });
  });

  group('parseVersionsTable', () {
    test('parses every data row, skipping header and separator', () {
      final sha = 'b'.padRight(40, 'b');
      final body =
          '## Versions\n'
          '\n'
          '_Content commit: `$sha`_\n'
          '\n'
          '| Package | Current | New | Bump |\n'
          '|---|---|---|---|\n'
          '| datadog_dio | 2.2.0 | 2.3.0 | minor |\n'
          '| datadog_flags | 1.0.0 | 2.0.0-beta.1 | prerelease |\n'
          '\n'
          '## Native SDK deltas\n';

      final rows = parseVersionsTable(body);

      expect(rows, hasLength(2));
      expect(rows[0].package, 'datadog_dio');
      expect(rows[0].fromVersion, '2.2.0');
      expect(rows[0].toVersion, '2.3.0');
      expect(rows[0].bump, 'minor');
      expect(rows[1].package, 'datadog_flags');
      expect(rows[1].bump, 'prerelease');
    });

    test('handles the "first release" bump fallback (two words)', () {
      final body =
          '## Versions\n'
          '\n'
          '| Package | Current | New | Bump |\n'
          '|---|---|---|---|\n'
          '| datadog_flutter_plugin_web | 0.0.0 | 1.0.0 | first release |\n';

      final rows = parseVersionsTable(body);

      expect(rows, hasLength(1));
      expect(rows.single.bump, 'first release');
    });

    test('empty when there is no ## Versions heading at all', () {
      expect(parseVersionsTable('nothing relevant here'), isEmpty);
    });

    test('parses a body with CRLF line endings', () {
      final body =
          '## Versions\r\n'
          '\r\n'
          '| Package | Current | New | Bump |\r\n'
          '|---|---|---|---|\r\n'
          '| datadog_dio | 2.2.0 | 2.3.0 | minor |\r\n'
          '| datadog_flags | 1.0.0 | 1.1.0 | minor |\r\n'
          '\r\n'
          '## Native SDK deltas\r\n';

      final rows = parseVersionsTable(body);

      expect(rows.map((r) => r.package), ['datadog_dio', 'datadog_flags']);
      expect(rows.last.bump, 'minor');
    });

    test('throws on a malformed row instead of dropping the package', () {
      final body =
          '## Versions\n'
          '\n'
          '| Package | Current | New | Bump |\n'
          '|---|---|---|---|\n'
          '| datadog_dio | 2.2.0 | 2.3.0 |\n';

      expect(() => parseVersionsTable(body), throwsA(isA<StateError>()));
    });
  });

  group('manifestPackagesFor with a PR body', () {
    late FixtureRepo fixture;

    setUp(() async {
      fixture = await FixtureRepo.create();
    });

    tearDown(() => fixture.delete());

    test('fills in relativePath via package discovery, derives prerelease '
        'from the bump column', () async {
      final body =
          '## Versions\n'
          '\n'
          '| Package | Current | New | Bump |\n'
          '|---|---|---|---|\n'
          '| datadog_dio | 2.2.0 | 2.3.0 | minor |\n'
          '| lonely_ios | 1.0.0 | 2.0.0-beta.1 | prerelease |\n';

      final entries = await manifestPackagesFor(
        parseVersionsTable(body),
        repoRoot: fixture.root.path,
        isSupport: false,
      );

      expect(entries, hasLength(2));
      final dio = entries.firstWhere((e) => e.package == 'datadog_dio');
      expect(dio.relativePath, 'packages/datadog_dio');
      expect(dio.prerelease, isFalse);

      final lonely = entries.firstWhere((e) => e.package == 'lonely_ios');
      expect(lonely.prerelease, isTrue);
    });

    test('throws for a package discovery can\'t find', () async {
      final body =
          '## Versions\n'
          '\n'
          '| Package | Current | New | Bump |\n'
          '|---|---|---|---|\n'
          '| does_not_exist | 1.0.0 | 1.1.0 | minor |\n';

      await expectLater(
        manifestPackagesFor(
          parseVersionsTable(body),
          repoRoot: fixture.root.path,
          isSupport: false,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('manifestPackagesFor', () {
    late FixtureRepo fixture;

    setUp(() async {
      fixture = await FixtureRepo.create();
    });

    tearDown(() => fixture.delete());

    test('threads isSupport through to every entry', () async {
      final entries = await manifestPackagesFor(
        [
          ParsedVersionRow(
            package: 'datadog_dio',
            fromVersion: '2.2.0',
            toVersion: '2.2.1',
            bump: 'patch',
          ),
        ],
        repoRoot: fixture.root.path,
        isSupport: true,
      );

      expect(entries.single.isSupport, isTrue);
      expect(entries.single.relativePath, 'packages/datadog_dio');
    });
  });
}
