// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// == LLM Pass 2b: Filter a native SDK's own changelog to customer-facing
//    sub-bullets.

import '../../version_bump.dart';
import '../prompt.dart';

/// Raw changelog entries from one native SDK, covering the version range a
/// package's `NativeSdkDelta` is picking up this release -- resolved via
/// `native_sdk_changelog.dart`'s `resolveNativeSdkChangelog`.
///
/// [impliedBump] decides which category the resulting entry lands in (see
/// `changelog.dart`'s `buildNativeSdkUpdateEntry`) -- computed in Dart from
/// the version delta itself (`NativeSdkDelta.getImpliedBump`), not asked of
/// the LLM, since it's a deterministic fact this tooling already knows.
class NativeSdkChangelogContext {
  final String displayName;
  final String targetVersion;
  final List<String> entries;
  final String changelogUrl;
  final VersionBumpType? impliedBump;

  const NativeSdkChangelogContext({
    required this.displayName,
    required this.targetVersion,
    required this.entries,
    required this.changelogUrl,
    this.impliedBump,
  });
}

/// A single-line entry, no category -- what this prompt asks for, distinct
/// from `changelog_entry_list_prompt.dart`'s three-category shape since
/// these become sub-bullets under one entry, not top-level entries in their
/// own right.
final _schema = {
  'type': 'object',
  'properties': {
    'entries': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'text': {
            'type': 'string',
            'description':
                'Full text of a single-line changelog entry, formatted as '
                'markdown.',
          },
        },
        'required': ['text'],
        'additionalProperties': false,
      },
    },
  },
  'required': ['entries'],
  'additionalProperties': false,
};

List<String> _fromJson(Map<String, dynamic> json) => (json['entries'] as List)
    .map((e) => (e as Map<String, dynamic>)['text'] as String)
    .toList();

String _text(NativeSdkChangelogContext context) {
  final entryText = context.entries.map((e) => '- $e').join('\n');
  return '''
You are preparing the sub-bullets that will appear under a single changelog line noting an update to the ${context.displayName} native SDK, inside a Flutter package's changelog. Below are that native SDK's own raw changelog entries, covering the version range being picked up in this release.

Your task: reduce these to a flat list of concise, customer-facing bullet points describing the user-visible impact on developers who use the Flutter package.

Include an entry for customer-facing changes: new features, behavior changes, and bug fixes.

Omit entries for:
- Anything labeled [MAINTENANCE], or otherwise about internal tooling, CI, build systems, or tests
- Internal refactors with no observable effect on the Flutter package's own consumers
- Changes only reachable through the native SDK's own internal API, not through the Flutter package's public API
- Session Replay or Feature Flags -- both are custom-implemented in Flutter rather than wrapping the native SDK's version of that feature, so changes and fixes to either in the native SDK's changelog don't apply here

Do not reproduce PR or issue links from the native repository (e.g. "See [#1234](...)" or "[#1234][]") -- drop that trailing reference entirely from each entry.

Do not add a link to the native SDK's own changelog yourself -- one is already shown above this list, so repeating it here would be redundant.

Style:
- Write from the user's perspective — describe the impact, not the implementation.
- Use present tense.
- Be concise: one sentence is almost always sufficient.
- Format each entry as plain markdown (inline `code` for public API identifiers).
- Drop any leading bracketed tag from the source entry (e.g. "[FEATURE]", "[BUGFIX]", "[IMPROVEMENT]", "[FIX]") -- write plain prose instead, consistent with the rest of this changelog.

Your response will adhere to the provided schema. Include no prose or formatting outside the JSON.

Use only the data provided below. Do not consult external sources.

<native-sdk-changelog name="${context.displayName}">
$entryText
</native-sdk-changelog>''';
}

/// Filters [context]'s native SDK changelog entries down to a flat,
/// customer-facing list of sub-bullets.
Prompt<List<String>> nativeSdkSubEntriesPrompt(
  NativeSdkChangelogContext context,
) => Prompt(text: _text(context), schema: _schema, fromJson: _fromJson);
