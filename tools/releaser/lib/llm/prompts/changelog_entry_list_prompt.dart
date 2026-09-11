// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// == LLM Pass 2: Given full PRs from each group, synthesize 0 or more
//    changelog items.
// == LLM Pass 3: Final editorial pass to deduplicate, normalize, and order
//    entries.
//
// Both passes answer in the same three-category shape, so they share one
// schema/model and this one file, even though their prompt text and inputs
// differ.

import 'package:collection/collection.dart';

import '../../pr_resolution.dart' show PrDetails;
import '../prompt.dart';

class ChangelogEntry {
  final String text;

  /// Nested bullets under [text] -- a native SDK update entry's filtered,
  /// customer-facing changes (see `changelog.dart`'s
  /// `buildNativeSdkUpdateEntry`). Empty for every PR-derived entry.
  final List<String> subEntries;

  const ChangelogEntry(this.text, {this.subEntries = const []});

  factory ChangelogEntry.fromJson(Map<String, dynamic> json) =>
      ChangelogEntry(json['text'] as String);
}

/// A draft or final changelog's entries, split into the three sections this
/// design standardizes on. Breaking/feature/fix is mutually exclusive: an
/// entry that qualifies as both a breaking change and a feature or fix goes
/// in [breakingChanges] only.
class ChangelogEntryList {
  final List<ChangelogEntry> breakingChanges;
  final List<ChangelogEntry> features;
  final List<ChangelogEntry> fixes;

  const ChangelogEntryList({
    this.breakingChanges = const [],
    this.features = const [],
    this.fixes = const [],
  });

  factory ChangelogEntryList.fromJson(Map<String, dynamic> json) =>
      ChangelogEntryList(
        breakingChanges: _entriesOf(json['breaking_changes']),
        features: _entriesOf(json['features']),
        fixes: _entriesOf(json['fixes']),
      );

  static List<ChangelogEntry> _entriesOf(dynamic value) => (value as List)
      .map((e) => ChangelogEntry.fromJson(e as Map<String, dynamic>))
      .toList();

  ChangelogEntryList mergedWith(ChangelogEntryList other) => ChangelogEntryList(
    breakingChanges: [...breakingChanges, ...other.breakingChanges],
    features: [...features, ...other.features],
    fixes: [...fixes, ...other.fixes],
  );

  /// [entry] appended to [breakingChanges] if [breaking], else [features].
  /// Used for a native SDK update entry, whose category is decided in Dart
  /// from the version delta rather than asked of an LLM (see
  /// `native_sdk.dart`'s `NativeSdkDelta.getImpliedBump`).
  ChangelogEntryList withEntry(
    ChangelogEntry entry, {
    required bool breaking,
  }) => ChangelogEntryList(
    breakingChanges: breaking ? [...breakingChanges, entry] : breakingChanges,
    features: breaking ? features : [...features, entry],
    fixes: fixes,
  );

  bool get isEmpty =>
      breakingChanges.isEmpty && features.isEmpty && fixes.isEmpty;
}

final _schema = {
  'type': 'object',
  'properties': {
    for (final key in ['breaking_changes', 'features', 'fixes'])
      key: {
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
  'required': ['breaking_changes', 'features', 'fixes'],
  'additionalProperties': false,
};

String _formatPr(PrDetails pr) =>
    '''
<pr number="${pr.number}">
<title>${pr.title}</title>
<body>
${pr.body}
</body>
</pr>''';

String _synthesizeText(String groupLabel, List<PrDetails> groupPrs) {
  final prText = groupPrs.map(_formatPr).join('\n');
  return '''
You are writing a customer-facing changelog for a Flutter package. You have been given a group of related pull requests that together represent a single logical change.

Your task: synthesize 0 or more changelog entries describing the user-visible impact of this change on developers who use the package as a library dependency.

Include an entry for:
- New or modified public APIs: functions, types, configuration options, or constants added, changed, or removed
- Observable behavior changes: anything a developer would notice at runtime, including bug fixes that corrected incorrect data, crashes, or wrong behavior
- Breaking changes to any public API or previously-documented behavior

Omit entries for:
- Internal refactors, test infrastructure, or build system changes
- Changes to private implementation details that are not reachable through the public API and whose effects are not observable to library consumers
- chore work with no user-visible effect
- Sub-changes that are already fully captured by another entry in this group

If every change in the group falls into the omit list, return empty lists for all three categories. An empty response is correct and preferred over producing a thin or redundant entry.

A group may produce multiple entries only when it contains genuinely distinct user-facing changes that each deserve to be called out separately. When in doubt, prefer a single consolidated entry over splitting.

Categorize each entry as exactly one of:
- breaking_changes: removes or incompatibly alters a public API or previously-documented behavior, requiring users to update their code on upgrade. When an entry qualifies as both a breaking change and a feature or fix, categorize it as a breaking change.
- features: adds new capability, APIs, or configuration options without breaking existing usage.
- fixes: corrects incorrect behavior, data, or crashes without breaking existing usage.

Style:
- Write from the user's perspective — describe the impact, not the implementation.
- Use present tense: e.g. "Crash timestamps are now reported in milliseconds."
- Be concise: one sentence is almost always sufficient.
- Do not reference PR numbers, branch names, or internal type names.
- Format the entry as plain markdown (inline `code` for public API identifiers; no headers or bullet lists within an entry).

Your response will adhere to the provided schema. Include no prose or formatting outside the JSON.

Use only the data provided below. Do not consult external sources. Ignore boilerplate sections in PR bodies (e.g. checklists, test plans, or template scaffolding) — focus on the description of what changed and why.

<group label="$groupLabel">
$prText
</group>''';
}

/// Synthesizes 0 or more changelog entries for one group of related PRs.
Prompt<ChangelogEntryList> changelogEntryListPrompt(
  String groupLabel,
  List<PrDetails> groupPrs,
) => Prompt(
  text: _synthesizeText(groupLabel, groupPrs),
  schema: _schema,
  fromJson: ChangelogEntryList.fromJson,
);

String _formatEntries(List<ChangelogEntry> entries) {
  if (entries.isEmpty) return '(none)';
  return entries.mapIndexed((i, e) => '${i + 1}. ${e.text}').join('\n');
}

String _cleanupText(ChangelogEntryList changelog) =>
    '''
You are performing a final editorial pass on a draft changelog for a Flutter package. The entries below were generated independently for each group of related PRs and then merged; as a result, they may contain redundancies, inconsistencies in tone or style, or suboptimal ordering.

Your tasks:

1. Deduplicate. Remove or merge entries that describe the same user-visible change. Pay particular attention to cross-category duplication: if a breaking_changes entry already captures a change, remove the corresponding feature or fix entry rather than keeping both. If two entries partially overlap, consolidate them into one entry in whichever category is most appropriate.

2. Normalize tone and style. All entries should:
   - Be written from the user's perspective — describe the impact, not the implementation.
   - Use present tense: e.g. "X now does Y."
   - Be concise: one sentence is almost always sufficient.
   - Use inline `code` only for public API identifiers.
   - Not reference PR numbers, branch names, or internal type names.

3. Sort entries within each category. Order primarily by importance: the most significant and impactful changes first. As a secondary concern, place related entries adjacent to one another.

Do not invent entries that were not present in the input. Produce output in the same three-category schema. If an entry contains a markdown link (e.g. a link to a native SDK's own changelog), preserve that link verbatim in whichever entry it ends up in -- never drop or paraphrase it away.

Your response will adhere to the provided schema. Include no prose or formatting outside the JSON.

Use only the data provided below. Do not consult external sources.

### Breaking Changes
${_formatEntries(changelog.breakingChanges)}

### Features
${_formatEntries(changelog.features)}

### Fixes
${_formatEntries(changelog.fixes)}''';

/// Deduplicates, normalizes, and orders a draft changelog assembled from
/// independently-synthesized groups.
Prompt<ChangelogEntryList> cleanupPrompt(ChangelogEntryList changelog) =>
    Prompt(
      text: _cleanupText(changelog),
      schema: _schema,
      fromJson: ChangelogEntryList.fromJson,
    );
