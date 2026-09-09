// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:releaser/llm/changelog.dart';
import 'package:releaser/native_sdk.dart';
import 'package:releaser/native_sdk_changelog.dart';
import 'package:releaser/pr_resolution.dart';
import 'package:releaser/version_bump.dart';
import 'package:test/test.dart';

import 'support/fake_ai_gateway_client.dart';

const _emptyEntryList = {
  'breaking_changes': <Map<String, dynamic>>[],
  'features': <Map<String, dynamic>>[],
  'fixes': <Map<String, dynamic>>[],
};

void main() {
  group('runGroupedPrsPrompt', () {
    final prs = [
      const PrDetails(number: 1, title: 'feat: add a thing', body: ''),
      const PrDetails(number: 2, title: 'fix: correct a bug', body: ''),
    ];

    test('returns the parsed groups when PR numbers match exactly', () async {
      final client = FakeAiGatewayClient([
        {
          'groups': [
            {
              'label': 'a thing',
              'prs': [
                {'number': 1, 'title': 'feat: add a thing'},
                {'number': 2, 'title': 'fix: correct a bug'},
              ],
            },
          ],
        },
      ]);

      final result = await runGroupedPrsPrompt(client, prs);

      expect(result.groups, hasLength(1));
      expect(result.groups.single.prs.map((p) => p.number), [1, 2]);
    });

    test('throws when the LLM drops a PR number', () async {
      final client = FakeAiGatewayClient([
        {
          'groups': [
            {
              'label': 'a thing',
              'prs': [
                {'number': 1, 'title': 'feat: add a thing'},
              ],
            },
          ],
        },
      ]);

      expect(() => runGroupedPrsPrompt(client, prs), throwsStateError);
    });

    test('throws when the LLM invents a PR number', () async {
      final client = FakeAiGatewayClient([
        {
          'groups': [
            {
              'label': 'a thing',
              'prs': [
                {'number': 1, 'title': 'feat: add a thing'},
                {'number': 2, 'title': 'fix: correct a bug'},
                {'number': 999, 'title': 'made up'},
              ],
            },
          ],
        },
      ]);

      expect(() => runGroupedPrsPrompt(client, prs), throwsStateError);
    });
  });

  group('runChangelogEntryListPrompt', () {
    test('parses breaking/feature/fix entries', () async {
      final client = FakeAiGatewayClient([
        {
          'breaking_changes': [
            {'text': 'Removed the old thing.'},
          ],
          'features': [
            {'text': 'Added a new thing.'},
          ],
          'fixes': <Map<String, dynamic>>[],
        },
      ]);

      final result = await runChangelogEntryListPrompt(client, 'a group', [
        const PrDetails(number: 1, title: 't', body: 'b'),
      ]);

      expect(result.breakingChanges.single.text, 'Removed the old thing.');
      expect(result.features.single.text, 'Added a new thing.');
      expect(result.fixes, isEmpty);
    });
  });

  group('runCleanupPrompt', () {
    test('returns the cleaned-up entry list', () async {
      final client = FakeAiGatewayClient([
        {
          ..._emptyEntryList,
          'fixes': [
            {'text': 'Fixed a bug.'},
          ],
        },
      ]);

      final result = await runCleanupPrompt(
        client,
        const ChangelogEntryList(
          fixes: [ChangelogEntry('Fixed a bug (duplicated).')],
        ),
      );

      expect(result.fixes.single.text, 'Fixed a bug.');
    });
  });

  group('ChangelogEntryList', () {
    test('mergedWith concatenates each category', () {
      const a = ChangelogEntryList(features: [ChangelogEntry('a')]);
      const b = ChangelogEntryList(
        features: [ChangelogEntry('b')],
        fixes: [ChangelogEntry('c')],
      );

      final merged = a.mergedWith(b);

      expect(merged.features.map((e) => e.text), ['a', 'b']);
      expect(merged.fixes.map((e) => e.text), ['c']);
    });

    test('isEmpty is true only when every category is empty', () {
      expect(const ChangelogEntryList().isEmpty, isTrue);
      expect(
        const ChangelogEntryList(fixes: [ChangelogEntry('x')]).isEmpty,
        isFalse,
      );
    });
  });

  group('generateChangelogEntries', () {
    test('short-circuits with no LLM calls for an empty PR list', () async {
      final client = FakeAiGatewayClient([]);

      final result = await generateChangelogEntries(client, []);

      expect(result.isEmpty, isTrue);
      expect(client.prompts, isEmpty);
    });

    test('runs group -> synthesize -> cleanup end to end', () async {
      final prs = [
        const PrDetails(number: 1, title: 'feat: add a thing', body: 'b1'),
        const PrDetails(number: 2, title: 'fix: correct a bug', body: 'b2'),
      ];

      final client = FakeAiGatewayClient([
        // Pass 1: group
        {
          'groups': [
            {
              'label': 'thing',
              'prs': [
                {'number': 1, 'title': 'feat: add a thing'},
              ],
            },
            {
              'label': 'bugfix',
              'prs': [
                {'number': 2, 'title': 'fix: correct a bug'},
              ],
            },
          ],
        },
        // Pass 2, group "thing"
        {
          ..._emptyEntryList,
          'features': [
            {'text': 'Adds a thing.'},
          ],
        },
        // Pass 2, group "bugfix"
        {
          ..._emptyEntryList,
          'fixes': [
            {'text': 'Fixes a bug.'},
          ],
        },
        // Pass 3: cleanup
        {
          ..._emptyEntryList,
          'features': [
            {'text': 'Adds a thing.'},
          ],
          'fixes': [
            {'text': 'Fixes a bug.'},
          ],
        },
      ]);

      final result = await generateChangelogEntries(client, prs);

      expect(result.features.single.text, 'Adds a thing.');
      expect(result.fixes.single.text, 'Fixes a bug.');
      expect(client.prompts, hasLength(4));
    });
  });

  group('synthesizeNativeSdkSubEntries', () {
    test('returns the filtered flat list of sub-entry texts', () async {
      final client = FakeAiGatewayClient([
        {
          'entries': [
            {'text': 'Adds UK1 site support.'},
          ],
        },
      ]);

      final result = await synthesizeNativeSdkSubEntries(
        client,
        const NativeSdkChangelogContext(
          displayName: 'Android',
          targetVersion: '3.12.1',
          entries: ['[FEATURE] Add UK1 site. See [#3595](url)'],
          changelogUrl:
              'https://github.com/DataDog/dd-sdk-android/blob/HEAD/CHANGELOG.md',
        ),
      );

      expect(result, ['Adds UK1 site support.']);
    });
  });

  group('buildNativeSdkUpdateEntry', () {
    test(
      'builds the exact wording with a markdown link, and nests subEntries',
      () {
        const context = NativeSdkChangelogContext(
          displayName: 'Android',
          targetVersion: '3.12.1',
          entries: [],
          changelogUrl:
              'https://github.com/DataDog/dd-sdk-android/blob/HEAD/CHANGELOG.md',
        );

        final entry = buildNativeSdkUpdateEntry(context, [
          'Adds UK1 site support.',
        ]);

        expect(
          entry.text,
          'Update to Android SDK 3.12.1. For a complete list of changes, see '
          'the [Android SDK CHANGELOG](https://github.com/DataDog/dd-sdk-android/blob/HEAD/CHANGELOG.md).',
        );
        expect(entry.subEntries, ['Adds UK1 site support.']);
      },
    );
  });

  group('resolveNativeSdkChangelogContexts', () {
    NativeSdkDelta delta({String? currentDeclaration, String? targetVersion}) =>
        NativeSdkDelta(
          sdk: NativeSdk.android,
          targetVersion: targetVersion,
          currentDeclaration: currentDeclaration,
        );

    test('builds a context from the resolved changelog sections', () async {
      final warnings = <String>[];

      final contexts = await resolveNativeSdkChangelogContexts(
        [delta(currentDeclaration: '3.12.0', targetVersion: '3.12.1')],
        fetchChangelog: (repoSlug) async => [
          const ChangelogSection(
            version: '3.12.1',
            entries: ['[BUGFIX] Fix R8 failures. See [#3642](url)'],
          ),
          const ChangelogSection(version: '3.12.0', entries: ['[FEATURE] X']),
        ],
        onWarning: warnings.add,
      );

      expect(contexts, hasLength(1));
      expect(contexts.single.displayName, 'Android');
      expect(contexts.single.targetVersion, '3.12.1');
      expect(contexts.single.entries, [
        '[BUGFIX] Fix R8 failures. See [#3642](url)',
      ]);
      expect(
        contexts.single.changelogUrl,
        'https://github.com/DataDog/dd-sdk-android/blob/HEAD/CHANGELOG.md',
      );
      // 3.12.0 -> 3.12.1 is a patch bump.
      expect(contexts.single.impliedBump, VersionBumpType.patch);
      expect(warnings, isEmpty);
    });

    test('a major native SDK bump is reflected in impliedBump', () async {
      final contexts = await resolveNativeSdkChangelogContexts(
        [delta(currentDeclaration: '3.12.0', targetVersion: '4.0.0')],
        fetchChangelog: (_) async => [
          const ChangelogSection(version: '4.0.0', entries: ['x']),
          const ChangelogSection(version: '3.12.0', entries: ['y']),
        ],
        onWarning: (_) => fail('should not warn'),
      );

      expect(contexts.single.impliedBump, VersionBumpType.major);
    });

    test(
      'skips with a warning instead of throwing when unresolvable',
      () async {
        final warnings = <String>[];

        final contexts = await resolveNativeSdkChangelogContexts(
          [delta(targetVersion: '3.12.1')], // no current declaration
          fetchChangelog: (_) async => throw StateError('should not be called'),
          onWarning: warnings.add,
        );

        expect(contexts, isEmpty);
        expect(warnings.single, contains('no resolvable current version'));
      },
    );

    test('skips a delta with no target (no change this run)', () async {
      final contexts = await resolveNativeSdkChangelogContexts(
        [delta(currentDeclaration: '3.12.0')],
        fetchChangelog: (_) async => throw StateError('should not be called'),
        onWarning: (_) => fail('should not warn'),
      );

      expect(contexts, isEmpty);
    });
  });

  group('generateChangelogEntries with native SDK contexts', () {
    const context = NativeSdkChangelogContext(
      displayName: 'Android',
      targetVersion: '3.12.1',
      entries: ['[FEATURE] Add UK1 site.'],
      changelogUrl:
          'https://github.com/DataDog/dd-sdk-android/blob/HEAD/CHANGELOG.md',
    );

    test(
      'appends one entry per context, without running it through cleanup',
      () async {
        final client = FakeAiGatewayClient([
          {
            'entries': [
              {'text': 'Adds UK1 site support.'},
            ],
          },
        ]);

        final result = await generateChangelogEntries(
          client,
          [],
          nativeSdkContexts: [context],
        );

        expect(client.prompts, hasLength(1)); // no group/synthesize/cleanup
        expect(result.features.single.text, contains(context.changelogUrl));
        expect(result.features.single.subEntries, ['Adds UK1 site support.']);
      },
    );

    test('a major implied bump files the entry as breaking', () async {
      const majorContext = NativeSdkChangelogContext(
        displayName: 'Android',
        targetVersion: '4.0.0',
        entries: ['[FEATURE] x'],
        changelogUrl:
            'https://github.com/DataDog/dd-sdk-android/blob/HEAD/CHANGELOG.md',
        impliedBump: VersionBumpType.major,
      );
      final client = FakeAiGatewayClient([
        {
          'entries': [
            {'text': 'x'},
          ],
        },
      ]);

      final result = await generateChangelogEntries(
        client,
        [],
        nativeSdkContexts: [majorContext],
      );

      expect(result.breakingChanges, hasLength(1));
      expect(result.features, isEmpty);
    });

    test('runs the PR pipeline and native SDK pass independently', () async {
      final client = FakeAiGatewayClient([
        // PR pipeline: group
        {
          'groups': [
            {
              'label': 'thing',
              'prs': [
                {'number': 1, 'title': 'feat: add a thing'},
              ],
            },
          ],
        },
        // PR pipeline: synthesize
        {
          ..._emptyEntryList,
          'features': [
            {'text': 'Adds a thing.'},
          ],
        },
        // PR pipeline: cleanup
        {
          ..._emptyEntryList,
          'features': [
            {'text': 'Adds a thing.'},
          ],
        },
        // Native SDK sub-entries
        {
          'entries': [
            {'text': 'Adds UK1 site support.'},
          ],
        },
      ]);

      final result = await generateChangelogEntries(
        client,
        [const PrDetails(number: 1, title: 'feat: add a thing', body: '')],
        nativeSdkContexts: [context],
      );

      expect(result.features.map((e) => e.text), [
        'Adds a thing.',
        contains('Update to Android SDK'),
      ]);
    });
  });

  group('renderChangelogSection', () {
    test('prints a maintenance placeholder when everything is empty', () {
      expect(
        renderChangelogSection(const ChangelogEntryList()),
        '- Maintenance release; no significant changes.\n',
      );
    });

    test('omits empty categories and renders the rest under their heading', () {
      final rendered = renderChangelogSection(
        const ChangelogEntryList(
          breakingChanges: [ChangelogEntry('Removed X.')],
          fixes: [ChangelogEntry('Fixed Y.'), ChangelogEntry('Fixed Z.')],
        ),
      );

      expect(rendered, '''
### Breaking Changes

- Removed X.

### Fixes

- Fixed Y.
- Fixed Z.''');
    });

    test('nests subEntries as indented sub-bullets', () {
      final rendered = renderChangelogSection(
        const ChangelogEntryList(
          features: [
            ChangelogEntry(
              'Update to Android SDK 3.12.1. For a complete list of '
              'changes, see the [Android SDK CHANGELOG](url).',
              subEntries: ['Adds UK1 site support.', 'Fixes a crash.'],
            ),
          ],
        ),
      );

      expect(rendered, '''
### Features

- Update to Android SDK 3.12.1. For a complete list of changes, see the [Android SDK CHANGELOG](url).
  - Adds UK1 site support.
  - Fixes a crash.''');
    });
  });
}
