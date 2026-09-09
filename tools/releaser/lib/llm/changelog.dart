// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

import '../github_cmd_wrapper.dart' show GithubCommandWrapper;
import '../native_sdk.dart' show NativeSdkDelta, nativeSdkImpliedBump;
import '../native_sdk_changelog.dart'
    show
        ChangelogFetcher,
        nativeSdkChangelogUrl,
        resolveNativeSdkChangelog,
        githubChangelogFetcher;
import '../pr_resolution.dart' show PrDetails, resolvePr;
import '../release_plan.dart' show PackagePlan;
import '../version_bump.dart';
import 'ai_gateway.dart';
import 'costs.dart';
import 'prompt.dart';

// == LLM Pass 1: Collect related PRs into groups with a common label

class GroupedPr {
  final int number;
  final String title;

  const GroupedPr({required this.number, required this.title});

  factory GroupedPr.fromJson(Map<String, dynamic> json) =>
      GroupedPr(number: json['number'] as int, title: json['title'] as String);
}

class PrGroup {
  final String label;
  final List<GroupedPr> prs;

  const PrGroup({required this.label, required this.prs});

  factory PrGroup.fromJson(Map<String, dynamic> json) => PrGroup(
    label: json['label'] as String,
    prs: (json['prs'] as List)
        .map((e) => GroupedPr.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class GroupedPrs {
  final List<PrGroup> groups;

  const GroupedPrs({required this.groups});

  factory GroupedPrs.fromJson(Map<String, dynamic> json) => GroupedPrs(
    groups: (json['groups'] as List)
        .map((e) => PrGroup.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

final groupedPrsSchema = {
  'type': 'object',
  'properties': {
    'groups': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'label': {
            'type': 'string',
            'description':
                'Short string describing the purpose of this group of PRs. '
                'Infer from the titles of constituent PRs.',
          },
          'prs': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'number': {
                  'type': 'integer',
                  'description':
                      'Integer PR number. Use the original PR number exactly.',
                },
                'title': {
                  'type': 'string',
                  'description':
                      'Single-line string describing the PR. Use the '
                      'original text exactly.',
                },
              },
              'required': ['number', 'title'],
              'additionalProperties': false,
            },
          },
        },
        'required': ['label', 'prs'],
        'additionalProperties': false,
      },
    },
  },
  'required': ['groups'],
  'additionalProperties': false,
};

String _groupedPrsPrompt(List<PrDetails> prs) {
  final prText = prs
      .map((pr) => '${pr.number.toString().padLeft(5)} ${pr.title}')
      .join('\n');
  return '''
You are preparing to write a customer-facing changelog for an SDK. Below is a list of PRs that have been merged since the last release.

Your task: group these PRs so that closely-related PRs can be considered together. A group should capture a coherent user-visible change: for example, several PRs that together implement one feature, or a fix that directly relates to a feature in the same release. PRs with no clear relationship to others should each be their own group.

Your response will be a JSON array where each element is an object representing a related group of one or more PRs. This JSON value will adhere to the provided schema. Your response will include no prose or formatting.

Use only the data provided below. Do not consult external sources.

<prs>
$prText
</prs>''';
}

/// Runs the grouping pass and sanity-checks that the PR numbers it
/// referenced exactly match the set of PRs it was given -- an LLM
/// inventing or dropping a PR number here would silently corrupt the
/// changelog, so this fails loudly instead.
Future<GroupedPrs> runGroupedPrsPrompt(
  AiGatewayClient client,
  List<PrDetails> prs, {
  LlmCostTracker? costTracker,
}) async {
  final result = await runStructuredPrompt(
    client,
    _groupedPrsPrompt(prs),
    groupedPrsSchema,
    GroupedPrs.fromJson,
    costTracker: costTracker,
    costLabel: 'GroupedPrs',
  );

  final expected = prs.map((pr) => pr.number).toSet();
  final got = result.groups.expand((g) => g.prs).map((pr) => pr.number).toSet();
  if (!const SetEquality<int>().equals(expected, got)) {
    throw StateError(
      'AI Gateway response PR numbers do not match input: expected '
      '${expected.join(',')}; got ${got.join(',')}',
    );
  }

  return result;
}

// == LLM Pass 2: Given full PRs from each group, synthesize 0 or more changelog items

class ChangelogEntry {
  final String text;

  /// Nested bullets under [text] -- a native SDK update entry's filtered,
  /// customer-facing changes (see [buildNativeSdkUpdateEntry]). Empty for
  /// every PR-derived entry.
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
  /// [nativeSdkImpliedBump]).
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

final changelogEntryListSchema = {
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

String _formatPrForPrompt(PrDetails pr) =>
    '''
<pr number="${pr.number}">
<title>${pr.title}</title>
<body>
${pr.body}
</body>
</pr>''';

String _changelogEntryListPrompt(String groupLabel, List<PrDetails> groupPrs) {
  final prText = groupPrs.map(_formatPrForPrompt).join('\n');
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

Future<ChangelogEntryList> runChangelogEntryListPrompt(
  AiGatewayClient client,
  String groupLabel,
  List<PrDetails> groupPrs, {
  LlmCostTracker? costTracker,
}) {
  return runStructuredPrompt(
    client,
    _changelogEntryListPrompt(groupLabel, groupPrs),
    changelogEntryListSchema,
    ChangelogEntryList.fromJson,
    costTracker: costTracker,
    costLabel: 'ChangelogEntryList($groupLabel)',
  );
}

// == LLM Pass 3: Final editorial pass to deduplicate, normalize, and order entries

String _formatEntriesForPrompt(List<ChangelogEntry> entries) {
  if (entries.isEmpty) return '(none)';
  return entries.mapIndexed((i, e) => '${i + 1}. ${e.text}').join('\n');
}

String _cleanupPrompt(ChangelogEntryList changelog) =>
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
${_formatEntriesForPrompt(changelog.breakingChanges)}

### Features
${_formatEntriesForPrompt(changelog.features)}

### Fixes
${_formatEntriesForPrompt(changelog.fixes)}''';

Future<ChangelogEntryList> runCleanupPrompt(
  AiGatewayClient client,
  ChangelogEntryList changelog, {
  LlmCostTracker? costTracker,
}) {
  return runStructuredPrompt(
    client,
    _cleanupPrompt(changelog),
    changelogEntryListSchema,
    ChangelogEntryList.fromJson,
    costTracker: costTracker,
    costLabel: 'Cleanup',
  );
}

// == LLM Pass 2b: Filter a native SDK's own changelog to customer-facing sub-bullets

/// Raw changelog entries from one native SDK, covering the version range a
/// package's [NativeSdkDelta] is picking up this release -- resolved via
/// `native_sdk_changelog.dart`'s `resolveNativeSdkChangelog`.
///
/// [impliedBump] decides which category the resulting entry lands in (see
/// [buildNativeSdkUpdateEntry]) -- computed in Dart from the version delta
/// itself ([nativeSdkImpliedBump]), not asked of the LLM, since it's a
/// deterministic fact this tooling already knows.
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

/// A single-line entry, no category -- what
/// [synthesizeNativeSdkSubEntries] asks for, distinct from
/// [changelogEntryListSchema]'s three-category shape since these become
/// sub-bullets under one entry, not top-level entries in their own right.
final _nativeSdkSubEntriesSchema = {
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

List<String> _parseNativeSdkSubEntries(Map<String, dynamic> json) =>
    (json['entries'] as List)
        .map((e) => (e as Map<String, dynamic>)['text'] as String)
        .toList();

String _nativeSdkSubEntriesPrompt(NativeSdkChangelogContext context) {
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

Future<List<String>> synthesizeNativeSdkSubEntries(
  AiGatewayClient client,
  NativeSdkChangelogContext context, {
  LlmCostTracker? costTracker,
}) {
  return runStructuredPrompt(
    client,
    _nativeSdkSubEntriesPrompt(context),
    _nativeSdkSubEntriesSchema,
    _parseNativeSdkSubEntries,
    costTracker: costTracker,
    costLabel: 'NativeSdkChangelog(${context.displayName})',
  );
}

/// The single top-level entry for a native SDK update -- exact wording and
/// link are built here, deterministically, rather than asked of an LLM:
/// "Update to Android SDK 3.13.0. For a complete list of changes, see the
/// [Android SDK CHANGELOG](url)." with [subEntries] nested underneath.
ChangelogEntry buildNativeSdkUpdateEntry(
  NativeSdkChangelogContext context,
  List<String> subEntries,
) => ChangelogEntry(
  'Update to ${context.displayName} SDK ${context.targetVersion}. For a '
  'complete list of changes, see the [${context.displayName} SDK '
  'CHANGELOG](${context.changelogUrl}).',
  subEntries: subEntries,
);

/// Resolves [deltas] into [NativeSdkChangelogContext]s ready for
/// [generateChangelogEntries] -- skips (reporting via [onWarning], not
/// silently) whichever deltas [resolveNativeSdkChangelog] couldn't find a
/// comparable baseline for, same as `preview_release.dart`'s `--verbose`
/// display.
Future<List<NativeSdkChangelogContext>> resolveNativeSdkChangelogContexts(
  List<NativeSdkDelta> deltas, {
  required ChangelogFetcher fetchChangelog,
  required void Function(String warning) onWarning,
}) async {
  final contexts = <NativeSdkChangelogContext>[];
  for (final delta in deltas) {
    final targetVersion = delta.targetVersion;
    if (targetVersion == null) continue;

    final result = await resolveNativeSdkChangelog(
      delta.sdk,
      currentDeclaration: delta.currentDeclaration,
      targetVersion: targetVersion,
      fetchChangelog: fetchChangelog,
    );
    if (result.warning != null) {
      onWarning(result.warning!);
      continue;
    }

    final entries = result.sections!.expand((s) => s.entries).toList();
    if (entries.isEmpty) continue;

    contexts.add(
      NativeSdkChangelogContext(
        displayName: delta.sdk.displayName,
        targetVersion: targetVersion,
        entries: entries,
        changelogUrl: nativeSdkChangelogUrl(delta.sdk),
        impliedBump: nativeSdkImpliedBump(delta),
      ),
    );
  }
  return contexts;
}

// == Orchestration

/// Runs the PR pipeline (group -> synthesize -> cleanup/dedup) against
/// [prs] -- the significant subset of PRs for one package's release --
/// then appends one entry per [nativeSdkContexts] (see
/// [resolveNativeSdkChangelogContexts]). Native SDK entries deliberately
/// skip the cleanup pass: their exact wording and link are built in Dart
/// (see [buildNativeSdkUpdateEntry]), and routing them through another LLM
/// call risks the cleanup pass paraphrasing away the link or flattening
/// the parent/sub-bullet structure the response schema doesn't carry.
/// `chore:`/`docs:`/`test:`-only commits are already excluded upstream by
/// `release_plan.dart`'s bump-weight filtering (see
/// `PackagePlan.contributingCommits`), so every [PrDetails] passed here is
/// assumed to already be in scope.
///
/// Returns an empty, un-prompted [ChangelogEntryList] when both [prs] and
/// [nativeSdkContexts] are empty -- no LLM calls for a release with
/// nothing to summarize.
Future<ChangelogEntryList> generateChangelogEntries(
  AiGatewayClient client,
  List<PrDetails> prs, {
  List<NativeSdkChangelogContext> nativeSdkContexts = const [],
  LlmCostTracker? costTracker,
}) async {
  if (prs.isEmpty && nativeSdkContexts.isEmpty) {
    return const ChangelogEntryList();
  }

  var changelog = const ChangelogEntryList();

  if (prs.isNotEmpty) {
    final groups = (await runGroupedPrsPrompt(
      client,
      prs,
      costTracker: costTracker,
    )).groups;

    for (final group in groups) {
      final numbers = group.prs.map((pr) => pr.number).toSet();
      final groupPrs = prs.where((pr) => numbers.contains(pr.number)).toList();
      final entries = await runChangelogEntryListPrompt(
        client,
        group.label,
        groupPrs,
        costTracker: costTracker,
      );
      changelog = changelog.mergedWith(entries);
    }

    changelog = await runCleanupPrompt(
      client,
      changelog,
      costTracker: costTracker,
    );
  }

  for (final context in nativeSdkContexts) {
    final subEntries = await synthesizeNativeSdkSubEntries(
      client,
      context,
      costTracker: costTracker,
    );
    changelog = changelog.withEntry(
      buildNativeSdkUpdateEntry(context, subEntries),
      breaking: context.impliedBump == VersionBumpType.major,
    );
  }

  return changelog;
}

/// Resolves everything [generateChangelogEntries] needs directly from
/// [packagePlan] -- each contributing commit's PR, that PR's full title and
/// body, and native SDK changelog contexts from [packagePlan]'s native SDK
/// deltas -- then runs the pipeline. The one call a caller holding a
/// [PackagePlan] needs.
Future<ChangelogEntryList> generateChangelogForPackage(
  AiGatewayClient client,
  PackagePlan packagePlan, {
  required GithubCommandWrapper github,
  required Logger logger,
  LlmCostTracker? costTracker,
}) async {
  final prNumbers = <int>{};
  for (final commit in packagePlan.contributingCommits) {
    if (commit.sha == null) continue;
    final resolved = await resolvePr(
      commit.sha!,
      commit.description,
      (sha) => github.searchMergedPrBySha(logger, sha),
    );
    if (resolved != null) prNumbers.add(resolved.number);
  }

  final prDetails = [
    for (final number in prNumbers) await github.fetchPrDetails(logger, number),
  ];

  final nativeSdkContexts = await resolveNativeSdkChangelogContexts(
    packagePlan.nativeSdkDeltas,
    fetchChangelog: githubChangelogFetcher(logger, github),
    onWarning: (w) => logger.warning('⚠️ $w'),
  );

  return generateChangelogEntries(
    client,
    prDetails,
    nativeSdkContexts: nativeSdkContexts,
    costTracker: costTracker,
  );
}

/// Renders [entries] as grouped-subsection markdown: `### Breaking Changes`/
/// `### Features`/`### Fixes`, each omitted when empty, under the
/// package's own `## {version}` heading -- this only produces the body,
/// not the heading itself.
String renderChangelogSection(ChangelogEntryList entries) {
  if (entries.isEmpty) {
    return '- Maintenance release; no significant changes.\n';
  }

  final buffer = StringBuffer();
  for (final (heading, list) in [
    ('### Breaking Changes', entries.breakingChanges),
    ('### Features', entries.features),
    ('### Fixes', entries.fixes),
  ]) {
    if (list.isEmpty) continue;
    buffer.writeln(heading);
    buffer.writeln();
    for (final entry in list) {
      buffer.writeln('- ${entry.text}');
      for (final sub in entry.subEntries) {
        buffer.writeln('  - $sub');
      }
    }
    buffer.writeln();
  }

  return buffer.toString().trimRight();
}
