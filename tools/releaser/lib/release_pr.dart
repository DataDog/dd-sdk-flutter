// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dependency_constraints.dart';
import 'llm/prompts/grouped_prs_prompt.dart' show PrGroup;
import 'release_plan.dart';

/// `chore(release): ...` -- `release` alone isn't a valid conventional-commit
/// type; matches this run's own commit messages.
String prTitle(List<PackagePlan> packages) {
  if (packages.length == 1) {
    final p = packages.single;
    return 'chore(release): ${p.package.name} ${p.newVersion}';
  }
  return 'chore(release): ${packages.length} packages';
}

/// Plain-text "what's shipping" list, shared by both commits' messages so
/// `git log` on either shows it without needing the other.
String versionSummary(List<PackagePlan> packages) => packages
    .map((p) {
      final bump = p.bumpLevel?.name ?? 'first release';
      return '- ${p.package.name}: ${p.currentVersion} -> ${p.newVersion} '
          '($bump)';
    })
    .join('\n');

/// The release PR's body: versions table, native SDK/warning call-outs,
/// then one section per package linking to its `CHANGELOG.md` at
/// [changelogRef] with the same PR-group summary (label + PR numbers)
/// `runGroupedPrsPrompt` produced for that changelog -- mirrors dd-sdk-cpp's
/// PR #346, extended to cover several packages in one PR.
///
/// [changelogRef] must be a commit SHA (the content commit), never a branch
/// or tag name -- a SHA stays resolvable and pinned to the exact content as
/// long as it's reachable from any ref, which it always is here (the
/// release-prep branch pre-merge, then `develop` once backported).
///
/// [groupsByPackage] is keyed by package name; missing/empty means no group
/// summary under that heading (e.g. a native-SDK-only release).
String prBody(
  List<PackagePlan> packages,
  List<StaleConsumerWarning> staleConsumerWarnings, {
  required bool publishValidationSkipped,
  required String repoSlug,
  required String changelogRef,
  required Map<String, List<PrGroup>> groupsByPackage,
}) {
  final buffer = StringBuffer();

  buffer.writeln('## Versions');
  buffer.writeln();
  buffer.writeln('| Package | Current | New | Bump |');
  buffer.writeln('|---|---|---|---|');
  for (final p in packages) {
    final bump = p.bumpLevel?.name ?? 'first release';
    buffer.writeln(
      '| ${p.package.name} | ${p.currentVersion} | ${p.newVersion} | $bump |',
    );
  }

  final nativeDeltas = packages.expand(
    (p) => p.nativeSdkDeltas.where((d) => d.targetVersion != null),
  );
  if (nativeDeltas.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('## Native SDK deltas');
    buffer.writeln();
    for (final delta in nativeDeltas) {
      buffer.writeln('- $delta');
    }
  }

  if (staleConsumerWarnings.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('## ⚠️ Stale consumer constraints');
    buffer.writeln();
    for (final warning in staleConsumerWarnings) {
      buffer.writeln('- $warning');
    }
  }

  final allWarnings = packages.expand((p) => p.warnings);
  if (allWarnings.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('## ⚠️ Warnings');
    buffer.writeln();
    for (final warning in allWarnings) {
      buffer.writeln('- $warning');
    }
  }

  for (final p in packages) {
    buffer.writeln();
    buffer.writeln(
      '## `${p.package.name}` ${p.currentVersion} → ${p.newVersion}',
    );
    buffer.writeln();
    final changelogUrl =
        'https://github.com/$repoSlug/blob/$changelogRef/'
        '${p.package.relativePath}/CHANGELOG.md';
    buffer.writeln(
      'See [CHANGELOG.md]($changelogUrl) for the full list of user-facing '
      'changes.',
    );

    final groups = groupsByPackage[p.package.name] ?? const <PrGroup>[];
    for (final group in groups) {
      buffer.writeln();
      buffer.writeln('#### ${group.label}');
      buffer.writeln();
      for (final pr in group.prs) {
        buffer.writeln('- #${pr.number}');
      }
    }
  }

  buffer.writeln();
  buffer.writeln(
    publishValidationSkipped
        ? '⚠️ `flutter pub publish --dry-run` was skipped '
              '(--skip-publish-validation) -- not verified for any package '
              'above.'
        : '`flutter pub publish --dry-run` passed for every package above.',
  );

  return buffer.toString();
}
