// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:collection/collection.dart';
import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:version/version.dart';

import 'conventional_commits.dart';
import 'git_history.dart';
import 'github_cmd_wrapper.dart';
import 'native_sdk.dart';
import 'package_discovery.dart';
import 'trigger_context.dart';
import 'version_updater.dart';

export 'trigger_context.dart';
export 'version_updater.dart';

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
  final String newVersion;

  /// Null for a first release whose history had nothing carrying semver
  /// weight.
  final VersionBumpType? bumpLevel;

  /// The commits that justified this release.
  final List<ConventionalCommit> contributingCommits;

  final List<NativeSdkDelta> nativeSdkDeltas;

  PackagePlan({
    required this.package,
    required this.currentVersion,
    required this.newVersion,
    this.bumpLevel,
    this.contributingCommits = const [],
    this.nativeSdkDeltas = const [],
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
/// [gitDir] and [nativeSdkGateways] are injectable so tests don't need a
/// real git history or network access; both default to real
/// implementations rooted at [RunContext.repoRoot].
Future<ReleasePlan> computeReleasePlan(
  RunContext ctx, {
  GitDir? gitDir,
  NativeSdkGateways? nativeSdkGateways,
}) async {
  final resolvedGitDir =
      gitDir ??
      await GitDir.fromExisting(ctx.repoRoot, allowSubdirectory: true);
  final github = GithubCommandWrapper(ctx.repoRoot);
  final gateways =
      nativeSdkGateways ??
      NativeSdkGateways(
        fetchLatest: (repoSlug) async {
          final release = await github.getLatestRelease(
            Logger('native_sdk'),
            repoSlug,
          );
          return release.tagName;
        },
        resolveCommitSha: (repoSlug, ref) =>
            github.getCommitSha(Logger('native_sdk'), repoSlug, ref),
        releaseExists: (repoSlug, version) async {
          final release = await github.getReleaseByTagName(
            Logger('native_sdk'),
            repoSlug,
            version,
          );
          return release != null;
        },
      );

  final groups = await _resolveGroups(ctx);
  final selected = _selectPackages(groups, ctx);

  final plans = <PackagePlan>[];
  for (final pkg in selected) {
    final plan = await _computePackagePlan(
      pkg,
      ctx,
      resolvedGitDir,
      gateways,
      isExplicitlyRequested: ctx.requestedPackages.contains(pkg.name),
    );
    if (plan != null) plans.add(plan);
  }

  return ReleasePlan(trigger: ctx.trigger, packages: plans);
}

Future<PackagePlan?> _computePackagePlan(
  DiscoveredPackage pkg,
  RunContext ctx,
  GitDir gitDir,
  NativeSdkGateways gateways, {
  required bool isExplicitlyRequested,
}) async {
  final nativeSdkDeltas = await _computeNativeSdkDeltas(pkg, ctx, gateways);
  final hasNativeSdkChange = nativeSdkDeltas.any((d) => d.isChange);

  switch (ctx.trigger) {
    case TriggerContext.patch:
      return await _computePatchPlan(pkg, gitDir, nativeSdkDeltas);
    case TriggerContext.preRelease:
      return await _computePrereleasePlan(pkg, ctx, gitDir, nativeSdkDeltas);
    case TriggerContext.mainline:
      return await _computeMainlinePlan(
        pkg,
        ctx,
        gitDir,
        nativeSdkDeltas,
        isExplicitlyRequested: isExplicitlyRequested,
        hasNativeSdkChange: hasNativeSdkChange,
      );
  }
}

Future<PackagePlan> _computePatchPlan(
  DiscoveredPackage pkg,
  GitDir gitDir,
  List<NativeSdkDelta> nativeSdkDeltas,
) async {
  final lastTag = await findLastReleaseTag(gitDir, pkg.name);
  final commits = await _conventionalCommitsSince(
    gitDir,
    pathspec: pkg.relativePath,
    sinceSha: lastTag?.objectSha,
  );

  for (final commit in commits) {
    final bump = commit.bumpType;
    if (bump == VersionBumpType.major || bump == VersionBumpType.minor) {
      throw StateError(
        'Commit looks like a ${bump!.name} change, which does not belong on '
        'a patch branch (only fixes are allowed here):\n'
        '${commit.type}: ${commit.description}',
      );
    }
  }

  final newVersion = lastTag == null
      ? pkg.version
      : Version.parse(
          _versionFromTag(lastTag, pkg.name),
        ).incrementPatch().toString();

  return PackagePlan(
    package: pkg,
    currentVersion: pkg.version,
    newVersion: newVersion,
    bumpLevel: VersionBumpType.patch,
    contributingCommits: commits,
    nativeSdkDeltas: nativeSdkDeltas,
  );
}

Future<PackagePlan> _computePrereleasePlan(
  DiscoveredPackage pkg,
  RunContext ctx,
  GitDir gitDir,
  List<NativeSdkDelta> nativeSdkDeltas,
) async {
  final lastTag = await findLastReleaseTag(gitDir, pkg.name);
  final base = Version.parse(
    lastTag != null ? _versionFromTag(lastTag, pkg.name) : pkg.version,
  );

  final Version newVersion;
  if (base.isPreRelease &&
      (ctx.prereleaseLabel == null ||
          base.preRelease.first == ctx.prereleaseLabel)) {
    newVersion = base.incrementPreRelease();
  } else if (ctx.prereleaseLabel != null) {
    newVersion = Version(
      base.major,
      base.minor,
      base.patch,
      preRelease: [ctx.prereleaseLabel!, '1'],
    );
  } else {
    throw StateError(
      'No prior pre-release tag for "${pkg.name}" at base version $base -- '
      'PRERELEASE_LABEL is required the first time a label is used against '
      'a given base version.',
    );
  }

  return PackagePlan(
    package: pkg,
    currentVersion: pkg.version,
    newVersion: newVersion.toString(),
    bumpLevel: VersionBumpType.prerelease,
    nativeSdkDeltas: nativeSdkDeltas,
  );
}

Future<PackagePlan?> _computeMainlinePlan(
  DiscoveredPackage pkg,
  RunContext ctx,
  GitDir gitDir,
  List<NativeSdkDelta> nativeSdkDeltas, {
  required bool isExplicitlyRequested,
  required bool hasNativeSdkChange,
}) async {
  final lastTag = await findLastReleaseTag(gitDir, pkg.name);
  final commits = await _conventionalCommitsSince(
    gitDir,
    pathspec: pkg.relativePath,
    sinceSha: lastTag?.objectSha,
  );

  var bump =
      VersionBumpType.parseOverride(ctx.bumpTypeOverride) ??
      aggregateBumpLevel(commits);

  if (bump == null) {
    if (!isExplicitlyRequested && !hasNativeSdkChange) {
      // Nothing changed for this package and nobody asked for it by name --
      // --all auto-detection leaves it out of this run entirely.
      return null;
    }
    // Explicitly requested, or only a native SDK bump is driving this
    // release: still worth a release, treated as a maintenance patch.
    bump = lastTag == null ? null : VersionBumpType.patch;
  }

  final newVersion = lastTag == null
      ? pkg.version
      : _applyBump(
          Version.parse(_versionFromTag(lastTag, pkg.name)),
          bump!,
        ).toString();

  return PackagePlan(
    package: pkg,
    currentVersion: pkg.version,
    newVersion: newVersion,
    bumpLevel: bump,
    contributingCommits: commits,
    nativeSdkDeltas: nativeSdkDeltas,
  );
}

Version _applyBump(Version base, VersionBumpType bump) {
  switch (bump) {
    case VersionBumpType.major:
      return base.incrementMajor();
    case VersionBumpType.minor:
      return base.incrementMinor();
    case VersionBumpType.patch:
      return base.incrementPatch();
    case VersionBumpType.prerelease:
      throw ArgumentError(
        '_applyBump does not handle prerelease bumps -- see '
        '_computePrereleasePlan for that path.',
      );
  }
}

/// A tag's name is `{package}/v{version}` -- strip the known prefix rather
/// than trusting [Tag.tag]'s shape blindly.
String _versionFromTag(Tag tag, String packageName) =>
    tag.tag.substring('$packageName/v'.length);

Future<List<NativeSdkDelta>> _computeNativeSdkDeltas(
  DiscoveredPackage pkg,
  RunContext ctx,
  NativeSdkGateways gateways,
) async {
  final files = resolveNativeDependencyFiles(pkg.absolutePath(ctx.repoRoot));
  final deltas = <NativeSdkDelta>[];

  if (files.iosPodspec != null) {
    final currentPin = readIosPodspecPin(files.iosPodspec!.readAsStringSync());
    final target = await resolveNativeSdkTarget(
      trigger: ctx.trigger,
      override: ctx.iosSdkVersionOverride,
      fetchLatest: () => gateways.fetchLatest(NativeSdk.ios.repoSlug),
      releaseExists: (version) =>
          gateways.releaseExists(NativeSdk.ios.repoSlug, version),
    );
    deltas.add(
      NativeSdkDelta(
        sdk: NativeSdk.ios,
        currentPin: currentPin,
        targetVersion: target,
      ),
    );
  }

  if (files.androidGradle != null) {
    final currentPin = readAndroidGradlePin(
      files.androidGradle!.readAsStringSync(),
    );
    final target = await resolveNativeSdkTarget(
      trigger: ctx.trigger,
      override: ctx.androidSdkVersionOverride,
      fetchLatest: () => gateways.fetchLatest(NativeSdk.android.repoSlug),
      releaseExists: (version) =>
          gateways.releaseExists(NativeSdk.android.repoSlug, version),
    );
    deltas.add(
      NativeSdkDelta(
        sdk: NativeSdk.android,
        currentPin: currentPin,
        targetVersion: target,
      ),
    );
  }

  if (files.cppCMakeLists.isNotEmpty) {
    final currentPin = readCppCMakePin(
      files.cppCMakeLists.first.readAsStringSync(),
    );
    final target = await resolveNativeSdkTarget(
      trigger: ctx.trigger,
      override: ctx.cppVersionOverride,
      fetchLatest: () => gateways.fetchLatest(NativeSdk.cpp.repoSlug),
      releaseExists: (version) =>
          gateways.releaseExists(NativeSdk.cpp.repoSlug, version),
    );
    // CMake's FetchContent_Declare has no field for pinning a tag and
    // verifying its commit -- the resolved SHA is what actually gets
    // written to GIT_TAG (see cmake_util.dart's pinCppVersion).
    final targetSha = target != null
        ? await gateways.resolveCommitSha(NativeSdk.cpp.repoSlug, target)
        : null;
    deltas.add(
      NativeSdkDelta(
        sdk: NativeSdk.cpp,
        currentPin: currentPin,
        targetVersion: target,
        targetSha: targetSha,
      ),
    );
  }

  return deltas;
}

/// [commitMessagesSince]'s raw messages, parsed into [ConventionalCommit]s
/// and narrowed to the ones that carry semver weight -- commits that fail
/// to parse, or parse but don't bump anything (`chore:`, `docs:`, etc.),
/// are dropped since nothing here cares about them either as bump input or
/// as a [PackagePlan.contributingCommits] entry.
Future<List<ConventionalCommit>> _conventionalCommitsSince(
  GitDir gitDir, {
  required String pathspec,
  String? sinceSha,
}) async {
  final messages = await commitMessagesSince(
    gitDir,
    pathspec: pathspec,
    sinceSha: sinceSha,
  );
  return messages
      .map(ConventionalCommit.parse)
      .nonNulls
      .where((c) => c.bumpType != null)
      .toList();
}

final _patchBranchPattern = RegExp(r'^release/([^/]+)/v\d+\.\d+\.x$');

/// Extracts the package name from a `release/{package}/v{major}.{minor}.x`
/// patch-branch name, or null if [branch] doesn't match that convention.
String? _packageNameFromPatchBranch(String branch) =>
    _patchBranchPattern.firstMatch(branch)?.group(1);

Future<List<PackageGroup>> _resolveGroups(RunContext ctx) async {
  final allGroups = await discoverPackages(ctx.repoRoot);

  if (ctx.trigger != TriggerContext.patch) {
    return allGroups;
  }

  // Patch branches never use topology -- a caret constraint already
  // tolerates a sibling staying behind, so only the one named package
  // moves, with no grouping applied to it.
  final packageName = _packageNameFromPatchBranch(ctx.currentBranch);
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
