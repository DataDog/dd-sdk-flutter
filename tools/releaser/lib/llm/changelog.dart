// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

import '../github_cmd_wrapper.dart';
import '../native_sdk.dart';
import '../native_sdk_changelog.dart';
import '../pr_resolution.dart';
import '../release_plan.dart';
import 'ai_gateway.dart';
import 'costs.dart';
import 'prompt.dart';
import 'prompts/changelog_entry_list_prompt.dart';
import 'prompts/grouped_prs_prompt.dart';
import 'prompts/native_sdk_sub_entries_prompt.dart';

export 'prompts/changelog_entry_list_prompt.dart'
    show ChangelogEntry, ChangelogEntryList;
export 'prompts/grouped_prs_prompt.dart' show GroupedPr, GroupedPrs, PrGroup;
export 'prompts/native_sdk_sub_entries_prompt.dart'
    show NativeSdkChangelogContext;

// == LLM Pass 1: Collect related PRs into groups with a common label

/// Runs the grouping pass (see `prompts/grouped_prs_prompt.dart`) and
/// sanity-checks that it partitioned the PRs it was given -- every input
/// number used, nothing invented, and each in exactly one group.
///
/// Inventing or dropping a number throws: the changelog would be wrong in a
/// way nothing downstream can detect, and there's no sound way to guess what
/// was meant. Assigning one PR to two groups is recoverable, though -- the
/// grouping is still complete, just not a partition -- so the repeat is
/// dropped from the later group and reported via [onWarning] rather than
/// failing the build. Left in, pass 2 would write that PR up twice, from two
/// angles, with nothing to reconcile them.
Future<GroupedPrs> runGroupedPrsPrompt(
  AiGatewayClient client,
  List<PrDetails> prs, {
  LlmCostTracker? costTracker,
  void Function(String warning)? onWarning,
}) async {
  final result = await runStructuredPrompt(
    client,
    groupedPrsPrompt(prs),
    costTracker: costTracker,
    costLabel: 'GroupedPrs',
  );

  final expected = prs.map((pr) => pr.number).toSet();
  final assigned = result.groups
      .expand((g) => g.prs)
      .map((pr) => pr.number)
      .toList();

  if (!const SetEquality<int>().equals(expected, assigned.toSet())) {
    throw StateError(
      'AI Gateway response PR numbers do not match input: expected '
      '${expected.join(',')}; got ${assigned.toSet().join(',')}',
    );
  }

  // Checked on the list, not the set the comparison above collapses to --
  // a repeat leaves the set equal while duplicating the entry downstream.
  if (assigned.length == expected.length) return result;

  final seen = <int>{};
  final duplicated = <int>[];
  final deduped = <PrGroup>[];

  for (final group in result.groups) {
    final kept = <GroupedPr>[];
    for (final pr in group.prs) {
      if (seen.add(pr.number)) {
        kept.add(pr);
      } else {
        duplicated.add(pr.number);
      }
    }
    // A group whose every PR was a repeat has nothing left to summarize.
    if (kept.isNotEmpty) deduped.add(PrGroup(label: group.label, prs: kept));
  }

  onWarning?.call(
    'AI Gateway put ${duplicated.map((n) => '#$n').join(', ')} in more than '
    'one group; keeping the first of each so the entry is written once.',
  );

  return GroupedPrs(groups: deduped);
}

// == LLM Pass 2: Given full PRs from each group, synthesize 0 or more changelog items

Future<ChangelogEntryList> runChangelogEntryListPrompt(
  AiGatewayClient client,
  String groupLabel,
  List<PrDetails> groupPrs, {
  LlmCostTracker? costTracker,
}) {
  return runStructuredPrompt(
    client,
    changelogEntryListPrompt(groupLabel, groupPrs),
    costTracker: costTracker,
    costLabel: 'ChangelogEntryList($groupLabel)',
  );
}

// == LLM Pass 3: Final editorial pass to deduplicate, normalize, and order entries

Future<ChangelogEntryList> runCleanupPrompt(
  AiGatewayClient client,
  ChangelogEntryList changelog, {
  LlmCostTracker? costTracker,
}) {
  return runStructuredPrompt(
    client,
    cleanupPrompt(changelog),
    costTracker: costTracker,
    costLabel: 'Cleanup',
  );
}

// == LLM Pass 2b: Filter a native SDK's own changelog to customer-facing sub-bullets

Future<List<String>> synthesizeNativeSdkSubEntries(
  AiGatewayClient client,
  NativeSdkChangelogContext context, {
  LlmCostTracker? costTracker,
}) {
  return runStructuredPrompt(
    client,
    nativeSdkSubEntriesPrompt(context),
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
        impliedBump: delta.getImpliedBump(),
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
  void Function(String warning)? onWarning,
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
      onWarning: onWarning,
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
    onWarning: (w) => logger.warning('⚠️ $w'),
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
