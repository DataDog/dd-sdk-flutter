// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:collection/collection.dart';

import 'package_discovery.dart';

/// Which of the three GitLab trigger contexts a run is happening under:
/// mainline (`develop`), patch (a standing `release/{package}/vX.Y.x`
/// branch), or pre-release (a whitelisted long-lived branch like `v4`).
enum TriggerContext { mainline, patch, preRelease }

final _patchBranchPattern = RegExp(r'^release/([^/]+)/v\d+\.\d+\.x$');

/// Extracts the package name from a `release/{package}/v{major}.{minor}.x`
/// patch-branch name, or null if [branch] doesn't match that convention.
String? packageNameFromPatchBranch(String branch) =>
    _patchBranchPattern.firstMatch(branch)?.group(1);

/// Everything about how a `prepare-release`/`preview-release` run was
/// invoked -- shared by both entry points so they can't compute different
/// plans from the same inputs.
class RunContext {
  final String repoRoot;
  final TriggerContext trigger;
  final String currentBranch;

  /// Explicit package names from `--packages`/`PACKAGES`; empty means
  /// `--all` (every package with pending commits). Not applicable on a
  /// patch branch, where the package is implied by [currentBranch].
  final List<String> requestedPackages;

  final String? bumpTypeOverride;
  final String? prereleaseLabel;
  final String? iosSdkVersionOverride;
  final String? androidSdkVersionOverride;
  final String? cppVersionOverride;

  RunContext({
    required this.repoRoot,
    required this.trigger,
    required this.currentBranch,
    this.requestedPackages = const [],
    this.bumpTypeOverride,
    this.prereleaseLabel,
    this.iosSdkVersionOverride,
    this.androidSdkVersionOverride,
    this.cppVersionOverride,
  });
}

/// The computed plan for a single releasing package.
class PackagePlan {
  final DiscoveredPackage package;
  final String currentVersion;

  // TODO: compute from conventional-commit bump detection / overrides.
  final String? newVersion;
  // TODO: compute alongside newVersion.
  final String? bumpLevel;
  // TODO: resolve from the commits contributing to this release.
  final List<String> contributingPrs;

  PackagePlan({
    required this.package,
    required this.currentVersion,
    this.newVersion,
    this.bumpLevel,
    this.contributingPrs = const [],
  });
}

class ReleasePlan {
  final TriggerContext trigger;
  final List<PackagePlan> packages;

  ReleasePlan({required this.trigger, required this.packages});
}

/// Computes what a release run would do, without writing anything. Shared
/// by `prepare_release.dart` (which acts on the result) and
/// `preview_release.dart` (which only prints it) so the two can't drift
/// apart.
///
/// TODO: conventional-commit bump detection, native SDK version checks, and
/// PR resolution -- `newVersion`/`bumpLevel`/`contributingPrs` are null or
/// empty on every returned plan until those land.
Future<ReleasePlan> computeReleasePlan(RunContext ctx) async {
  final groups = await _resolveGroups(ctx);
  final selected = _selectPackages(groups, ctx);

  final plans = selected
      .map((pkg) => PackagePlan(package: pkg, currentVersion: pkg.version))
      .toList();

  return ReleasePlan(trigger: ctx.trigger, packages: plans);
}

Future<List<PackageGroup>> _resolveGroups(RunContext ctx) async {
  final allGroups = await discoverPackages(ctx.repoRoot);

  if (ctx.trigger != TriggerContext.patch) {
    return allGroups;
  }

  // Patch branches never use topology -- a caret constraint already
  // tolerates a sibling staying behind, so only the one named package
  // moves, with no grouping applied to it.
  final packageName = packageNameFromPatchBranch(ctx.currentBranch);
  if (packageName == null) {
    throw StateError(
      'Branch "${ctx.currentBranch}" does not match the '
      'release/{package}/v{major}.{minor}.x patch-branch convention.',
    );
  }

  final pkg = allGroups
      .expand((group) => group.members)
      .where((pkg) => pkg.name == packageName)
      .firstOrNull;
  if (pkg == null) {
    throw StateError(
      'No discovered package named "$packageName" (from patch branch '
      '"${ctx.currentBranch}").',
    );
  }

  return [
    PackageGroup(key: pkg.name, members: [pkg]),
  ];
}

List<DiscoveredPackage> _selectPackages(
  List<PackageGroup> groups,
  RunContext ctx,
) {
  // Groups are already topologically ordered internally; flattening in
  // discovery order preserves that, and cross-group order doesn't matter
  // since independent groups/singletons publish in parallel.
  final all = groups.expand((group) => group.members).toList();

  if (ctx.requestedPackages.isEmpty) return all;

  if (ctx.trigger == TriggerContext.patch) {
    // A patch run's single package is already implied by currentBranch (see
    // _resolveGroups) -- an inherited --packages/PACKAGES filter shouldn't
    // be able to narrow or wipe that out, so it doesn't apply here.
    return all;
  }

  final requested = ctx.requestedPackages.toSet();
  final discovered = all.map((pkg) => pkg.name).toSet();
  final unknown = requested.difference(discovered);
  if (unknown.isNotEmpty) {
    throw StateError('Requested package(s) not found: ${unknown.join(', ')}.');
  }

  return all.where((pkg) => requested.contains(pkg.name)).toList();
}
