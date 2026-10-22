// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:releaser/native_sdk.dart';
import 'package:releaser/native_sdk_changelog.dart';
import 'package:test/test.dart';

// Trimmed real snippets from each SDK's actual CHANGELOG.md, kept verbatim
// enough to exercise each heading style: iOS's "# X.Y.Z / DD-MM-YYYY" with
// an "# Unreleased" section on top, Android's "# X.Y.Z / YYYY-MM-DD", and
// C++'s "## X.Y.Z" with "###" sub-headings that must NOT be treated as
// version boundaries.
const _iosSnippet = '''
# Unreleased

- [FEATURE] Add remoteConfiguration. See [#2919][]

# 3.16.0 / 19-08-2026

- [FEATURE] Add an experimental Core Animation recording pipeline. See [#3127][]
- [FIX] Fix EXC_BREAKPOINT crash. [#3134][]

# 3.15.0 / 05-08-2026

- [FEATURE] Add support for UK1 Datadog Site. See [#3087][]
''';

const _androidSnippet = '''
# 3.12.1 / 2026-07-16

* [BUGFIX] Fix R8 failures due to missing SourceLines annotation. See [#3642](url)

# 3.12.0 / 2026-07-15

* [FEATURE] Continuous Profiling. See [#3622](url)
* [BUGFIX] Fix interop wireframe positioning. See [#3611](url)
''';

const _cppSnippet = '''
## 0.7.0

### Breaking Changes

- The source value reported by the SDK has changed to cpp.

## 0.6.0

### Breaking Changes

- dd_core_config_t now stores string fields in fixed-size inline buffers.

### Features

- TTID can now be reported by calling Rum::ReportAppDisplayInitialized().
''';

void main() {
  group('parseChangelog', () {
    test('iOS: drops Unreleased, keeps date suffix out of the version', () {
      final sections = parseChangelog(_iosSnippet);

      expect(sections.map((s) => s.version), ['3.16.0', '3.15.0']);
      expect(sections[0].entries, [
        '- [FEATURE] Add an experimental Core Animation recording pipeline. See [#3127][]',
        '- [FIX] Fix EXC_BREAKPOINT crash. [#3134][]',
      ]);
    });

    test(
      'Android: parses the same heading shape with a different date format',
      () {
        final sections = parseChangelog(_androidSnippet);

        expect(sections.map((s) => s.version), ['3.12.1', '3.12.0']);
        expect(sections[1].entries, hasLength(2));
      },
    );

    test(
      'C++: a "##" version heading is a boundary, "###" sub-headings are not',
      () {
        final sections = parseChangelog(_cppSnippet);

        expect(sections.map((s) => s.version), ['0.7.0', '0.6.0']);
        // The 0.6.0 section folds both its Breaking Changes and Features
        // sub-headings' lines into one entries list, not two sections.
        expect(sections[1].entries, [
          '### Breaking Changes',
          '- dd_core_config_t now stores string fields in fixed-size inline buffers.',
          '### Features',
          '- TTID can now be reported by calling Rum::ReportAppDisplayInitialized().',
        ]);
      },
    );

    test('content with no version heading at all parses to no sections', () {
      expect(
        parseChangelog('# Unreleased\n\n- nothing shipped yet\n'),
        isEmpty,
      );
    });
  });

  group('normalizeVersion', () {
    test('strips a CocoaPods constraint operator', () {
      expect(normalizeVersion('~> 3.5.0'), '3.5.0');
    });

    test('pulls the version out of an SPM version argument', () {
      expect(normalizeVersion('from: "3.0.0"'), '3.0.0');
    });

    test('is a no-op on an already-bare version', () {
      expect(normalizeVersion('3.5.0'), '3.5.0');
    });

    test('null in, null out', () {
      expect(normalizeVersion(null), isNull);
    });

    test('null when nothing semver-shaped is present', () {
      expect(normalizeVersion('develop'), isNull);
    });
  });

  group('sectionsBetween', () {
    final sections = parseChangelog(_iosSnippet);

    test(
      'slices from just after fromVersion (older) through toVersion (newer), inclusive',
      () {
        final result = sectionsBetween(
          sections,
          fromVersion: '3.15.0',
          toVersion: '3.16.0',
        );

        expect(result?.map((s) => s.version), ['3.16.0']);
      },
    );

    test('empty when fromVersion and toVersion are the same', () {
      final result = sectionsBetween(
        sections,
        fromVersion: '3.16.0',
        toVersion: '3.16.0',
      );

      expect(result, isEmpty);
    });

    test('null when fromVersion is not a heading in the changelog', () {
      final result = sectionsBetween(
        sections,
        fromVersion: '9.9.9',
        toVersion: '3.16.0',
      );

      expect(result, isNull);
    });

    test('null when toVersion is not a heading in the changelog', () {
      final result = sectionsBetween(
        sections,
        fromVersion: '3.15.0',
        toVersion: '9.9.9',
      );

      expect(result, isNull);
    });

    test('null when toVersion is older than fromVersion (misuse guard)', () {
      final result = sectionsBetween(
        sections,
        fromVersion: '3.16.0',
        toVersion: '3.15.0',
      );

      expect(result, isNull);
    });
  });

  group('resolveNativeSdkChangelog', () {
    Future<List<ChangelogSection>> fakeFetch(String repoSlug) async {
      expect(repoSlug, NativeSdk.ios.repoSlug);
      return parseChangelog(_iosSnippet);
    }

    test('resolves a normal bump to its sections', () async {
      final result = await resolveNativeSdkChangelog(
        NativeSdk.ios,
        currentDeclaration: '~> 3.15.0',
        targetVersion: '3.16.0',
        fetchChangelog: fakeFetch,
      );

      expect(result.warning, isNull);
      expect(result.sections?.map((s) => s.version), ['3.16.0']);
    });

    test(
      'skips with a warning when there is no resolvable current version',
      () async {
        final result = await resolveNativeSdkChangelog(
          NativeSdk.ios,
          currentDeclaration: 'develop',
          targetVersion: '3.16.0',
          fetchChangelog: (_) async =>
              throw StateError('fetchChangelog should not have been called'),
        );

        expect(result.sections, isNull);
        expect(result.warning, contains('no resolvable current version'));
      },
    );

    test(
      'skips with a warning when neither version is found upstream',
      () async {
        final result = await resolveNativeSdkChangelog(
          NativeSdk.ios,
          currentDeclaration: '~> 1.0.0',
          targetVersion: '3.16.0',
          fetchChangelog: fakeFetch,
        );

        expect(result.sections, isNull);
        expect(result.warning, contains('could not find'));
      },
    );
  });
}
