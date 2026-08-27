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
        releaseExists: (repoSlug, version) =>
            github.releaseExists(Logger('native_sdk'), repoSlug, version),
      );

  _validateTriggerInputs(ctx);

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

/// Rejects per-run overrides that the trigger the run is happening under has
/// no way to honour, rather than accepting and silently ignoring them.
///
/// Only the mainline path derives a bump level at all: a patch branch forces
/// `patch` by definition, and a pre-release branch's bump comes from the
/// prerelease counter. A `BUMP_TYPE` on either would read as "this release is
/// a major" and quietly not be.
void _validateTriggerInputs(RunContext ctx) {
  final bumpType = ctx.bumpTypeOverride;
  if (bumpType == null || bumpType.isEmpty) return;

  switch (ctx.trigger) {
    case TriggerContext.mainline:
      // Parsed (and rejected if unrecognized) where it's applied.
      return;
    case TriggerContext.patch:
      throw StateError(
        'BUMP_TYPE="$bumpType" does not apply on a patch branch -- a patch '
        'release always increments the patch level of its release line, and '
        'a commit that would justify anything more is rejected outright. '
        'Clear BUMP_TYPE, or release from develop instead.',
      );
    case TriggerContext.preRelease:
      throw StateError(
        'BUMP_TYPE="$bumpType" does not apply on a pre-release branch -- the '
        'version comes from the prerelease counter against the target '
        'declared in pubspec.yaml. Use PRERELEASE_LABEL to start a new label, '
        'or bump pubspec.yaml to move to a new target version.',
      );
  }
}

Future<PackagePlan?> _computePackagePlan(
  DiscoveredPackage pkg,
  RunContext ctx,
  GitDir gitDir,
  NativeSdkGateways gateways, {
  required bool isExplicitlyRequested,
}) async {
  // Each trigger asks a different question of the tag history, and each asks
  // it in the query rather than filtering afterwards:
  //   mainline    -- the last *stable* release. A pre-release line's tags
  //                  (`4.0.0-beta.3` off `v4`) sort higher but haven't shipped.
  //   patch       -- the last release on the branch's own release line.
  //   pre-release -- the last release at the exact version pubspec declares as
  //                  the target, the only tag that can continue its counter.
  final lastTag = await findLastReleaseTag(
    gitDir,
    pkg.name,
    versionScope: switch (ctx.trigger) {
      TriggerContext.mainline => null,
      TriggerContext.patch => _versionScopeFromPatchBranch(ctx.currentBranch),
      TriggerContext.preRelease => _versionScopeFromTarget(pkg.version),
    },
    stableOnly: ctx.trigger == TriggerContext.mainline,
  );
  final commits = await _conventionalCommitsSince(
    gitDir,
    pathspec: pkg.relativePath,
    sinceSha: lastTag?.tag.objectSha,
  );
  final files = resolveNativeDependencyFiles(pkg.absolutePath(ctx.repoRoot));

  // Whether this package releases at all is decided here, before anything
  // touches the network -- resolving native SDK targets for a package that
  // turns out to have nothing to ship is pure waste.
  //
  // Eligibility must come from the package's actual changes, never from
  // BUMP_TYPE alone: a targeted override like BUMP_TYPE=major would otherwise
  // sweep every discovered package into a major release of the entire repo.
  // Patch and pre-release runs release whatever they were pointed at.
  if (ctx.trigger == TriggerContext.mainline &&
      aggregateBumpLevel(commits) == null &&
      !isExplicitlyRequested &&
      !_hasForcedNativeUpdate(files, ctx)) {
    return null;
  }

  final nativeSdkDeltas = await _computeNativeSdkDeltas(files, ctx, gateways);

  return switch (ctx.trigger) {
    TriggerContext.patch => _computePatchPlan(
      pkg,
      commits,
      lastTag,
      nativeSdkDeltas,
    ),
    TriggerContext.preRelease => _computePrereleasePlan(
      pkg,
      ctx,
      commits,
      lastTag,
      nativeSdkDeltas,
    ),
    TriggerContext.mainline => _computeMainlinePlan(
      pkg,
      ctx,
      commits,
      lastTag,
      nativeSdkDeltas,
    ),
  };
}

/// Whether this run carries an explicit native SDK version override for an SDK
/// [files] shows the package actually depends on.
///
/// Scoped that way deliberately: an `IOS_SDK_VERSION` on an `--all` run should
/// make the iOS packages eligible, not sweep every pure-Dart package in the
/// repo into the release alongside them.
bool _hasForcedNativeUpdate(NativeDependencyFiles files, RunContext ctx) =>
    ((files.iosPodspec != null || files.iosSpmManifest != null) &&
        ctx.iosSdkVersionOverride != null) ||
    (files.androidGradle != null && ctx.androidSdkVersionOverride != null) ||
    (files.cppCMakeLists.isNotEmpty && ctx.cppVersionOverride != null);

PackagePlan _computePatchPlan(
  DiscoveredPackage pkg,
  List<ConventionalCommit> commits,
  ReleaseTag? lastTag,
  List<NativeSdkDelta> nativeSdkDeltas,
) {
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

  return PackagePlan(
    package: pkg,
    currentVersion: pkg.version,
    newVersion: lastTag == null
        ? pkg.version
        : lastTag.version.incrementPatch().toString(),
    bumpLevel: VersionBumpType.patch,
    contributingCommits: commits,
    nativeSdkDeltas: nativeSdkDeltas,
  );
}

PackagePlan _computePrereleasePlan(
  DiscoveredPackage pkg,
  RunContext ctx,
  List<ConventionalCommit> commits,
  ReleaseTag? lastTag,
  List<NativeSdkDelta> nativeSdkDeltas,
) {
  final target = Version.parse(pkg.version);

  // [lastTag] is already scoped to [target]'s exact major.minor.patch (see
  // _versionScopeFromTarget), so any tag found here is by construction one
  // that continues this pre-release line -- either an earlier counter for it
  // or the stable release it was leading up to. With none, the pubspec's own
  // declared version is the base.
  final base = lastTag?.version ?? target;

  final Version newVersion;
  if (base.isPreRelease &&
      (ctx.prereleaseLabel == null ||
          base.preRelease.first == ctx.prereleaseLabel)) {
    newVersion = base.incrementPreRelease();
  } else if (lastTag != null && !base.isPreRelease) {
    // [lastTag] is a *stable* tag for this exact target version (e.g. the
    // target line was already released as 4.0.0 and pubspec.yaml hasn't
    // been bumped since) -- a new pre-release here would sort below that
    // already-published release (`4.0.0-beta.1` < `4.0.0`).
    throw StateError(
      'Package "${pkg.name}" version $target has already been released '
      'stably as ${lastTag.tag.tag} -- bump the version in pubspec.yaml '
      'before starting a new pre-release line.',
    );
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
    // The bump here is counter-based rather than commit-derived, but the
    // commits are still what the changelog is written from.
    contributingCommits: commits,
    nativeSdkDeltas: nativeSdkDeltas,
  );
}

PackagePlan _computeMainlinePlan(
  DiscoveredPackage pkg,
  RunContext ctx,
  List<ConventionalCommit> commits,
  ReleaseTag? lastTag,
  List<NativeSdkDelta> nativeSdkDeltas,
) {
  // With nothing auto-detected, this package is here because it was asked for
  // by name or a forced native SDK update is driving it -- still worth a
  // release, treated as a maintenance patch.
  //
  // [lastTag] is always a stable version here (see [findLastReleaseTag]'s
  // `stableOnly`), so bumping from it is unconditionally right: after a
  // long-lived pre-release line merges back, the baseline is still the last
  // stable release and the line's own breaking commits are what carry the
  // version to the major it was leading up to.
  final bump =
      VersionBumpType.parseOverride(ctx.bumpTypeOverride) ??
      aggregateBumpLevel(commits) ??
      (lastTag == null ? null : VersionBumpType.patch);

  return PackagePlan(
    package: pkg,
    currentVersion: pkg.version,
    newVersion: lastTag == null
        ? pkg.version
        : _applyBump(lastTag.version, bump!).toString(),
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

/// Resolves what each native SDK this package depends on should be pinned to
/// this run, one [NativeSdkDelta] per SDK it actually ships a manifest for.
///
/// Purely a *target* resolution -- see [NativeSdkDelta] for why there's no
/// "current pin" to compare against. What each SDK resolves to (latest,
/// an explicit override, or no change on a patch branch) is
/// [resolveNativeSdkTarget]'s call.
Future<List<NativeSdkDelta>> _computeNativeSdkDeltas(
  NativeDependencyFiles files,
  RunContext ctx,
  NativeSdkGateways gateways,
) async {
  final perSdkFiles = {
    NativeSdk.ios: (
      files: [?files.iosPodspec, ?files.iosSpmManifest],
      override: ctx.iosSdkVersionOverride,
    ),
    NativeSdk.android: (
      files: [?files.androidGradle],
      override: ctx.androidSdkVersionOverride,
    ),
    NativeSdk.cpp: (
      files: files.cppCMakeLists,
      override: ctx.cppVersionOverride,
    ),
  };

  final deltas = <NativeSdkDelta>[];
  for (final MapEntry(key: sdk, value: (:files, :override))
      in perSdkFiles.entries) {
    if (files.isEmpty) continue;

    final target = await resolveNativeSdkTarget(
      trigger: ctx.trigger,
      override: override,
      fetchLatest: () => gateways.fetchLatest(sdk.repoSlug),
      releaseExists: (version) => gateways.releaseExists(sdk.repoSlug, version),
    );

    deltas.add(
      NativeSdkDelta(
        sdk: sdk,
        targetVersion: target,
        // CMake's FetchContent_Declare has no field for pinning a tag and
        // verifying its commit -- the resolved SHA is what actually gets
        // written to GIT_TAG (see cmake_util.dart's pinCppVersion).
        targetSha: sdk == NativeSdk.cpp && target != null
            ? await gateways.resolveCommitSha(sdk.repoSlug, target)
            : null,
        files: files,
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

final _patchBranchPattern = RegExp(
  r'^release/(?<package>[^/]+)/v(?<major>\d+)\.(?<minor>\d+)\.x$',
);

/// Extracts the package name from a `release/{package}/v{major}.{minor}.x`
/// patch-branch name, or null if [branch] doesn't match that convention.
String? _packageNameFromPatchBranch(String branch) =>
    _patchBranchPattern.firstMatch(branch)?.namedGroup('package');

/// The `{major}.{minor}` release line from a
/// `release/{package}/v{major}.{minor}.x` patch-branch name, as a scope for
/// [findLastReleaseTag] -- `patch` is left open, since any patch level on that
/// line is a valid predecessor. Only called once [_resolveGroups] has already
/// validated the branch matches the convention, so a non-match here would be a
/// bug in that validation.
({int major, int minor, int? patch}) _versionScopeFromPatchBranch(
  String branch,
) {
  final match = _patchBranchPattern.firstMatch(branch)!;
  return (
    major: int.parse(match.namedGroup('major')!),
    minor: int.parse(match.namedGroup('minor')!),
    patch: null,
  );
}

/// The exact `{major}.{minor}.{patch}` a pre-release run is working towards,
/// from the package's declared pubspec version, as a scope for
/// [findLastReleaseTag].
///
/// Deliberately drops any pre-release suffix the pubspec itself carries: a
/// pubspec sitting at `4.0.0-beta.1` mid-line is still targeting `4.0.0`, and
/// its own earlier betas are exactly the tags that must be found.
({int major, int minor, int? patch}) _versionScopeFromTarget(String version) {
  final target = Version.parse(version);
  return (major: target.major, minor: target.minor, patch: target.patch);
}

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
