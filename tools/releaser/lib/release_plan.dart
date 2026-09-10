// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:version/version.dart';

import 'conventional_commits.dart';
import 'git_history.dart';
import 'github_cmd_wrapper.dart';
import 'native_sdk.dart';
import 'package_discovery.dart';
import 'published_versions.dart';
import 'trigger_context.dart';
import 'version_bump.dart';

export 'published_versions.dart'
    show PublishedVersions, PublishedVersionsGateway;
export 'trigger_context.dart';
export 'version_bump.dart';

final _log = Logger('release_plan');

/// The only [PackageGroup.key] whose members get native SDK version
/// resolution. Other packages' podspec/gradle files are never read for
/// this purpose, even if one declares a Datadog dependency.
const _nativeSdkEligibleGroupKey = 'datadog_flutter_plugin';

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

  /// When true, naming any member of a federated group in
  /// [requestedPackages] widens selection to every member of that group --
  /// see `_selectPackages`. Those extra siblings are still not
  /// "explicitly requested" themselves: each is only included if it's
  /// independently eligible (qualifying commits, or a forced native SDK
  /// update). A no-op for a singleton group.
  final bool includeFederated;

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
    this.includeFederated = false,
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

  /// What is currently published, or `pubspec.yaml`'s version for a package
  /// that has never been published.
  ///
  /// Read from pub.dev rather than `pubspec.yaml` for anything published:
  /// every release ends by bumping pubspec to a "next potential" version that
  /// doesn't exist, so pubspec routinely names something never shipped
  /// (`3.6.0` while `3.5.0` is the newest release).
  final String currentVersion;

  final String newVersion;

  /// Null for a promotion or a first release -- nothing was "bumped".
  final VersionBumpType? bumpLevel;

  /// The commits that justified this release.
  final List<ConventionalCommit> contributingCommits;

  final List<NativeSdkDelta> nativeSdkDeltas;

  /// Native dependency constraints, outside [_nativeSdkEligibleGroupKey],
  /// that have changed since this package's last published release --
  /// e.g. a hand-edit to raise the minimum supported dd-sdk-ios version to
  /// pick up a new feature. Not resolved or pinned by this tooling, just
  /// reported.
  final List<NativeDependencyChange> nativeDependencyChanges;

  /// Anything a human should see about how this plan was derived -- notably
  /// a published version whose tag is missing, which widens the commit range.
  final List<String> warnings;

  PackagePlan({
    required this.package,
    required this.currentVersion,
    required this.newVersion,
    this.bumpLevel,
    this.contributingCommits = const [],
    this.nativeSdkDeltas = const [],
    this.nativeDependencyChanges = const [],
    this.warnings = const [],
  });
}

/// A native dependency's constraint as declared now vs. as declared at
/// [PackagePlan.currentVersion] -- see [PackagePlan.nativeDependencyChanges].
class NativeDependencyChange {
  final NativeSdk sdk;
  final String? previous;
  final String? current;

  NativeDependencyChange({
    required this.sdk,
    required this.previous,
    required this.current,
  });

  @override
  String toString() => '${sdk.name}: $previous -> $current';
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
/// The gateways are injectable so tests need neither network nor a real git
/// history; all default to real implementations rooted at
/// [RunContext.repoRoot].
Future<ReleasePlan> computeReleasePlan(
  RunContext ctx, {
  GitDir? gitDir,
  NativeSdkGateways? nativeSdkGateways,
  PublishedVersionsGateway? publishedVersions,
}) async {
  _validateTriggerInputs(ctx);

  final resolvedGitDir =
      gitDir ??
      await GitDir.fromExisting(ctx.repoRoot, allowSubdirectory: true);
  final published = publishedVersions ?? fetchPublishedVersions;
  final gateways = nativeSdkGateways ?? _githubGateways(ctx.repoRoot);

  final groups = await _resolveGroups(ctx);
  final selected = _selectPackages(groups, ctx);

  final plans = <PackagePlan>[];
  for (final pkg in selected) {
    final plan = await _computePackagePlan(
      pkg,
      ctx,
      resolvedGitDir,
      gateways,
      await published(pkg.name),
      isExplicitlyRequested: ctx.requestedPackages.contains(pkg.name),
    );
    if (plan != null) plans.add(plan);
  }

  return ReleasePlan(trigger: ctx.trigger, packages: plans);
}

NativeSdkGateways _githubGateways(String repoRoot) {
  final github = GithubCommandWrapper(repoRoot);
  return NativeSdkGateways(
    fetchLatest: (repoSlug) async =>
        (await github.getLatestRelease(_log, repoSlug)).tagName,
    resolveCommitSha: (repoSlug, ref) =>
        github.getCommitSha(_log, repoSlug, ref),
    releaseExists: (repoSlug, version) async =>
        await github.getReleaseByTagName(_log, repoSlug, version) != null,
  );
}

/// Rejects per-run overrides the run has no coherent way to honour, rather
/// than accepting and silently reinterpreting them.
///
/// Only the mainline path derives a bump level at all: a patch branch forces
/// `patch` by definition, and a pre-release branch's version comes from the
/// prerelease counter. A `BUMP_TYPE` on either would read as "this release is
/// a major" and quietly not be.
///
/// Even on mainline it requires an explicit `PACKAGES`. "Override the computed
/// bump" is only meaningful about packages the caller named: combined with
/// `--all` it re-levels whatever happened to qualify, so a single `fix:` typo
/// ships as a major.
void _validateTriggerInputs(RunContext ctx) {
  final bumpType = ctx.bumpTypeOverride;
  if (bumpType == null || bumpType.isEmpty) return;

  switch (ctx.trigger) {
    case TriggerContext.mainline:
      if (ctx.requestedPackages.isEmpty) {
        throw StateError(
          'BUMP_TYPE="$bumpType" requires an explicit PACKAGES list -- it '
          'applies uniformly to every package in the run, so on an --all run '
          'it would re-level whichever packages happened to qualify, turning '
          'an unrelated fix into a $bumpType release. Name the packages this '
          'bump is for, or clear BUMP_TYPE and let the commits decide.',
        );
      }
      // Otherwise parsed (and rejected if unrecognized) where it's applied.
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
        'version comes from the prerelease counter against a target computed '
        'from the last stable release. Use PRERELEASE_LABEL to start a new '
        'label.',
      );
  }
}

Future<PackagePlan?> _computePackagePlan(
  DiscoveredPackage pkg,
  RunContext ctx,
  GitDir gitDir,
  NativeSdkGateways gateways,
  PublishedVersions published, {
  required bool isExplicitlyRequested,
}) async {
  // Two questions, answered separately because on a pre-release line they
  // have different answers:
  //
  //   versionBase -- what the new version is derived from.
  //   commitBase  -- what "since we last shipped" means, for the changelog
  //                  range and for whether this package ships at all.
  //
  // They coincide on mainline (a stable release supersedes the whole line)
  // and on a patch branch (confined to its own line). A pre-release run has
  // to resolve its target first, because both its baselines are scoped to
  // that target's line -- see [_prereleaseTarget].
  final Version? versionBase;
  final Version? commitBase;
  final warnings = <String>[];

  switch (ctx.trigger) {
    case TriggerContext.mainline:
      final latestPrerelease = published.latest;
      if (published.latestStable != null) {
        versionBase = commitBase = published.latestStable;
      } else if (latestPrerelease != null) {
        // Promote to the base version the pre-release already declares
        // ("1.0.0-preview.14" -> "1.0.0"), not pubspec.yaml.
        versionBase = Version(
          latestPrerelease.major,
          latestPrerelease.minor,
          latestPrerelease.patch,
        );
        commitBase = latestPrerelease;
      } else {
        versionBase = commitBase = null;
      }
    case TriggerContext.patch:
      final (major, minor) = _releaseLineFromPatchBranch(ctx.currentBranch);
      versionBase = commitBase = published.latestOn(major, minor);
      if (versionBase == null) {
        throw StateError(
          'Branch "${ctx.currentBranch}" patches the $major.$minor.x line of '
          '"${pkg.name}", but no $major.$minor release of it has been '
          'published. A patch branch builds on an existing release; there is '
          'nothing here to patch. Check the branch name, or release '
          '$major.$minor.0 from develop first.',
        );
      }
    case TriggerContext.preRelease:
      final target = await _prereleaseTarget(pkg, published, gitDir, warnings);
      versionBase = target;
      // Scoped to the target's own line. The global newest release is the
      // wrong answer here: a concurrent pre-release effort (a `v5` branch
      // publishing `5.0.0-alpha.1` while `v4` is still shipping betas) is
      // unrelated to this line, and taking its tag as the range start would
      // both mis-measure "what's new" and reject this line's next beta for
      // sorting below it.
      commitBase =
          published.prereleasesAt(target).lastOrNull ?? published.latestStable;
  }

  final (sinceSha, rangeWarnings) = await _commitRangeStart(
    gitDir,
    pkg.name,
    published,
    commitBase,
  );
  for (final warning in rangeWarnings) {
    if (!warnings.contains(warning)) warnings.add(warning);
  }
  final commits = await _conventionalCommitsSince(
    gitDir,
    pathspec: pkg.relativePath,
    sinceSha: sinceSha,
  );

  final files = resolveNativeDependencyFiles(pkg.absolutePath(ctx.repoRoot));

  // See [_nativeSdkEligibleGroupKey]. Non-eligible packages' files are
  // still discovered, for [_nativeDependencyChanges] below.
  final isNativeSdkEligible = pkg.groupKey == _nativeSdkEligibleGroupKey;

  // Whether this package releases at all is decided before anything touches
  // the network -- resolving native SDK targets for a package with nothing to
  // ship is pure waste.
  //
  // A patch run is exempt: its single package comes from the branch name, and
  // a patch branch exists precisely because something needs shipping from it.
  if (ctx.trigger != TriggerContext.patch &&
      aggregateBumpLevel(commits) == null &&
      !isExplicitlyRequested &&
      !(isNativeSdkEligible && _hasForcedNativeUpdate(files, ctx))) {
    return null;
  }

  final nativeSdkDeltas = isNativeSdkEligible
      ? await _computeNativeSdkDeltas(
          pkg,
          files,
          ctx,
          gitDir,
          published,
          gateways,
        )
      : const <NativeSdkDelta>[];

  final nativeDependencyChanges = isNativeSdkEligible
      ? const <NativeDependencyChange>[]
      : await _nativeDependencyChanges(pkg, files, ctx, gitDir, published);

  final currentVersion = published.latest?.toString() ?? pkg.version;

  return switch (ctx.trigger) {
    TriggerContext.patch => _computePatchPlan(
      pkg,
      currentVersion,
      commits,
      versionBase,
      nativeSdkDeltas,
      nativeDependencyChanges,
      warnings,
    ),
    TriggerContext.preRelease => _computePrereleasePlan(
      pkg,
      ctx,
      currentVersion,
      commits,
      versionBase,
      published,
      nativeSdkDeltas,
      nativeDependencyChanges,
      warnings,
    ),
    TriggerContext.mainline => _computeMainlinePlan(
      pkg,
      ctx,
      currentVersion,
      commits,
      versionBase,
      isPromotion: published.latestStable == null && published.latest != null,
      nativeSdkDeltas: nativeSdkDeltas,
      nativeDependencyChanges: nativeDependencyChanges,
      warnings: warnings,
    ),
  };
}

/// The version a pre-release run is working towards.
///
/// Computed, not declared: the last stable release plus the bump aggregated
/// from every commit since it (`3.5.0` + a `feat!` on `v4` -> `4.0.0`). This
/// is the same derivation a stable release would use, which is what makes a
/// pre-release "mainline plus a suffix" and makes the path self-correcting --
/// once `4.0.0` ships stably the base moves on and the target becomes
/// `4.1.0`.
///
/// Note this aggregates from the last **stable** release, not the last
/// pre-release. Measuring from the previous beta would make the target
/// collapse as the line progresses: after `4.0.0-beta.1`, a lone `fix:` would
/// compute `3.5.1` instead of `4.0.0`.
///
/// A package with no stable release takes `pubspec.yaml`'s version, which for
/// something never published is the only declaration of what it's aiming at.
Future<Version> _prereleaseTarget(
  DiscoveredPackage pkg,
  PublishedVersions published,
  GitDir gitDir,
  List<String> warnings,
) async {
  final stableBase = published.latestStable;
  if (stableBase == null) return Version.parse(pkg.version);

  final (sinceSha, stableWarnings) = await _commitRangeStart(
    gitDir,
    pkg.name,
    published,
    stableBase,
  );
  for (final warning in stableWarnings) {
    if (!warnings.contains(warning)) warnings.add(warning);
  }

  final bump = aggregateBumpLevel(
    await _conventionalCommitsSince(
      gitDir,
      pathspec: pkg.relativePath,
      sinceSha: sinceSha,
    ),
  );

  // Nothing since the last stable carries semver weight -- this package is
  // only here because it was named or a native SDK override is driving it, so
  // the next patch is what it's aiming at.
  return _applyBump(stableBase, bump ?? VersionBumpType.patch);
}

/// The sha a commit range starts from, plus anything a human should know
/// about how it was chosen.
///
/// pub.dev can legitimately know a version git can't locate -- a release
/// published before its tag was pushed, or whose tag never was. Two of
/// `datadog_flutter_plugin`'s 65 published versions are in that state today.
/// Rather than reconciling the two sources up front (which would report the
/// same historical gaps on every run until people stopped reading them), this
/// walks back to the newest version that does resolve and says so. A stale
/// entry is only ever consulted when it's the newest on the line being
/// released, so the noise is bounded to the case that actually matters.
Future<(String?, List<String>)> _commitRangeStart(
  GitDir gitDir,
  String packageName,
  PublishedVersions published,
  Version? from,
) async {
  if (from == null) return (null, <String>[]);

  final candidates = published.versions
      .where((v) => v <= from)
      .toList()
      .reversed;

  for (final version in candidates) {
    final sha = await tagSha(gitDir, '$packageName/v$version');
    if (sha == null) continue;
    if (version == from) return (sha, <String>[]);
    return (
      sha,
      [
        '$from is published but has no tag -- the commit range falls back to '
            'v$version, so this changelog may repeat entries already shipped '
            'in $from.',
      ],
    );
  }

  return (
    null,
    [
      'No tag could be found for any published version of $packageName up to '
          '$from -- the commit range covers the package\'s entire history and '
          'this changelog will almost certainly repeat released entries.',
    ],
  );
}

PackagePlan _computePatchPlan(
  DiscoveredPackage pkg,
  String currentVersion,
  List<ConventionalCommit> commits,
  Version? versionBase,
  List<NativeSdkDelta> nativeSdkDeltas,
  List<NativeDependencyChange> nativeDependencyChanges,
  List<String> warnings,
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
    currentVersion: currentVersion,
    newVersion: versionBase == null
        ? pkg.version
        : versionBase.incrementPatch().toString(),
    // Nothing to increment from means nothing was bumped -- see the same
    // reasoning in _computeMainlinePlan.
    bumpLevel: versionBase == null ? null : VersionBumpType.patch,
    contributingCommits: commits,
    nativeSdkDeltas: nativeSdkDeltas,
    nativeDependencyChanges: nativeDependencyChanges,
    warnings: warnings,
  );
}

PackagePlan _computeMainlinePlan(
  DiscoveredPackage pkg,
  RunContext ctx,
  String currentVersion,
  List<ConventionalCommit> commits,
  Version? versionBase, {
  required bool isPromotion,
  required List<NativeSdkDelta> nativeSdkDeltas,
  required List<NativeDependencyChange> nativeDependencyChanges,
  required List<String> warnings,
}) {
  // Never published: pubspec.yaml is the only declaration of the first version.
  if (versionBase == null) {
    return PackagePlan(
      package: pkg,
      currentVersion: currentVersion,
      newVersion: pkg.version,
      contributingCommits: commits,
      nativeSdkDeltas: nativeSdkDeltas,
      nativeDependencyChanges: nativeDependencyChanges,
      warnings: warnings,
    );
  }

  // versionBase is already the promotion target -- not something to bump.
  if (isPromotion) {
    return PackagePlan(
      package: pkg,
      currentVersion: currentVersion,
      newVersion: versionBase.toString(),
      contributingCommits: commits,
      nativeSdkDeltas: nativeSdkDeltas,
      nativeDependencyChanges: nativeDependencyChanges,
      warnings: warnings,
    );
  }

  // With nothing auto-detected, this package is here because it was asked for
  // by name or a forced native SDK update is driving it -- still worth a
  // release, treated as a maintenance patch.
  final bump =
      VersionBumpType.parseOverride(ctx.bumpTypeOverride) ??
      aggregateBumpLevel(commits) ??
      VersionBumpType.patch;

  return PackagePlan(
    package: pkg,
    currentVersion: currentVersion,
    newVersion: _applyBump(versionBase, bump).toString(),
    bumpLevel: bump,
    contributingCommits: commits,
    nativeSdkDeltas: nativeSdkDeltas,
    nativeDependencyChanges: nativeDependencyChanges,
    warnings: warnings,
  );
}

/// A pre-release is mainline plus a suffix: the target is computed the same
/// way a stable release would be, then a counter is appended.
///
/// The target is deliberately *not* read from `pubspec.yaml`, which would be
/// a second source of truth free to disagree with what has actually shipped.
/// Computing it also makes the path self-correcting: once `4.0.0` ships
/// stably the base moves on, the target becomes `4.1.0` or `5.0.0`, and no
/// state is left claiming otherwise.
PackagePlan _computePrereleasePlan(
  DiscoveredPackage pkg,
  RunContext ctx,
  String currentVersion,
  List<ConventionalCommit> commits,
  Version? target,
  PublishedVersions published,
  List<NativeSdkDelta> nativeSdkDeltas,
  List<NativeDependencyChange> nativeDependencyChanges,
  List<String> warnings,
) {
  target!;
  final counter = published.prereleasesAt(target).lastOrNull;
  final label = ctx.prereleaseLabel;

  final Version newVersion;
  if (counter != null && (label == null || counter.preRelease.first == label)) {
    newVersion = counter.incrementPreRelease();
  } else if (published.hasStableAt(target)) {
    // Can only happen when the target was reached by a path that doesn't
    // consult the commits (a never-published package taking its version from
    // pubspec, say) -- a new pre-release here would sort below a release
    // that already exists.
    throw StateError(
      'Package "${pkg.name}" target $target has already been released stably '
      '-- a pre-release against it would sort below the published version.',
    );
  } else if (label != null) {
    newVersion = Version(
      target.major,
      target.minor,
      target.patch,
      preRelease: [label, '1'],
    );
  } else {
    throw StateError(
      'No prior pre-release for "${pkg.name}" at target $target -- '
      'PRERELEASE_LABEL is required the first time a label is used against a '
      'given target version.',
    );
  }

  // Whatever the branches above decided, a release has to move forward.
  //
  // Asserted as an invariant rather than enumerated as another case, because
  // the ways to go backwards outnumber the ways to go forwards: labels are
  // compared lexically by semver, so `beta` after `rc.1` restarts at
  // `beta.1` -- already published, and below the latest release. It doesn't
  // self-correct either: `rc.1` stays the highest at this target, so every
  // subsequent run proposes that same `beta.1` again.
  //
  // Scoped to this target's own line, not to the newest release anywhere: a
  // concurrent effort publishing `5.0.0-alpha.1` says nothing about whether
  // `4.0.0-beta.2` moves this line forward, and comparing against it would
  // block the `v4` line entirely.
  final highestAtTarget = published.prereleasesAt(target).lastOrNull;
  if (highestAtTarget != null && newVersion <= highestAtTarget) {
    throw StateError(
      'Pre-release $newVersion for "${pkg.name}" would not move forward from '
      'the published $highestAtTarget. Pre-release labels are ordered '
      'lexically (alpha < beta < rc), so a label earlier than the one already '
      'shipped restarts below it. Continue with a label that sorts after '
      '"${highestAtTarget.preRelease.first}".',
    );
  }

  return PackagePlan(
    package: pkg,
    currentVersion: currentVersion,
    newVersion: newVersion.toString(),
    bumpLevel: VersionBumpType.prerelease,
    // The version is counter-based rather than commit-derived, but the
    // commits are still what the changelog is written from.
    contributingCommits: commits,
    nativeSdkDeltas: nativeSdkDeltas,
    nativeDependencyChanges: nativeDependencyChanges,
    warnings: warnings,
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

/// [file]'s content as it existed in [pkg]'s last published version's git
/// history, or null if there's no published version, no tag resolves (see
/// [tagSha]), or [file] didn't exist at that commit.
Future<String?> _lastPublishedContent(
  DiscoveredPackage pkg,
  PublishedVersions published,
  RunContext ctx,
  GitDir gitDir,
  File? file,
) async {
  final latest = published.latest;
  if (latest == null || file == null) return null;
  return fileContentAtTag(
    gitDir,
    '${pkg.name}/v$latest',
    p.relative(file.path, from: ctx.repoRoot),
  );
}

/// One [NativeSdkDelta] per SDK [pkg] ships a manifest for.
Future<List<NativeSdkDelta>> _computeNativeSdkDeltas(
  DiscoveredPackage pkg,
  NativeDependencyFiles files,
  RunContext ctx,
  GitDir gitDir,
  PublishedVersions published,
  NativeSdkGateways gateways,
) async {
  Future<String?> historicalContent(File? file) =>
      _lastPublishedContent(pkg, published, ctx, gitDir, file);

  final iosPodspecContent = await historicalContent(files.iosPodspec);
  final iosSpmContent = await historicalContent(files.iosSpmManifest);
  final androidContent = await historicalContent(files.androidGradle);
  final cppContent = await historicalContent(files.cppCMakeLists.firstOrNull);

  final perSdkFiles = {
    NativeSdk.ios: (
      files: [?files.iosPodspec, ?files.iosSpmManifest],
      override: ctx.iosSdkVersionOverride,
      current: currentIosDeclaration(
        podspecContent: iosPodspecContent,
        spmContent: iosSpmContent,
      ),
    ),
    NativeSdk.android: (
      files: [?files.androidGradle],
      override: ctx.androidSdkVersionOverride,
      current: currentAndroidDeclaration(androidContent),
    ),
    NativeSdk.cpp: (
      files: files.cppCMakeLists,
      override: ctx.cppVersionOverride,
      current: currentCppDeclaration(cppContent),
    ),
  };

  final deltas = <NativeSdkDelta>[];
  for (final MapEntry(key: sdk, value: (:files, :override, :current))
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
        currentDeclaration: current,
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

/// Native dependency constraints, for a package outside
/// [_nativeSdkEligibleGroupKey], that have changed since its own last
/// published release -- see [PackagePlan.nativeDependencyChanges].
Future<List<NativeDependencyChange>> _nativeDependencyChanges(
  DiscoveredPackage pkg,
  NativeDependencyFiles files,
  RunContext ctx,
  GitDir gitDir,
  PublishedVersions published,
) async {
  // Require a resolvable tag, not just published.latest != null -- else a
  // package whose latest published version has no tag (e.g.
  // datadog_session_replay's 1.0.0-preview.14) falsely reports every
  // dependency as newly added.
  final latest = published.latest;
  if (latest == null || await tagSha(gitDir, '${pkg.name}/v$latest') == null) {
    return const [];
  }

  Future<String?> historicalContent(File? file) =>
      _lastPublishedContent(pkg, published, ctx, gitDir, file);

  final changes = <NativeDependencyChange>[];

  void checkFor(NativeSdk sdk, String? current, String? previous) {
    if (current == previous) return;
    changes.add(
      NativeDependencyChange(sdk: sdk, previous: previous, current: current),
    );
  }

  if (files.iosPodspec != null || files.iosSpmManifest != null) {
    checkFor(
      NativeSdk.ios,
      currentIosDeclaration(
        podspecContent: files.iosPodspec?.readAsStringSync(),
        spmContent: files.iosSpmManifest?.readAsStringSync(),
      ),
      currentIosDeclaration(
        podspecContent: await historicalContent(files.iosPodspec),
        spmContent: await historicalContent(files.iosSpmManifest),
      ),
    );
  }

  if (files.androidGradle != null) {
    checkFor(
      NativeSdk.android,
      currentAndroidDeclaration(files.androidGradle!.readAsStringSync()),
      currentAndroidDeclaration(await historicalContent(files.androidGradle)),
    );
  }

  if (files.cppCMakeLists.isNotEmpty) {
    final file = files.cppCMakeLists.first;
    checkFor(
      NativeSdk.cpp,
      currentCppDeclaration(file.readAsStringSync()),
      currentCppDeclaration(await historicalContent(file)),
    );
  }

  return changes;
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
String? packageNameFromPatchBranch(String branch) =>
    _patchBranchPattern.firstMatch(branch)?.namedGroup('package');

/// Auto-detects a run's trigger context from [currentBranch] where that's
/// unambiguous, and defaults to mainline otherwise.
///
/// Patch is recognised unconditionally by branch-name convention. Pre-release
/// is deliberately *not* guessed here. To preview a pre-release run with an
/// explicit `--trigger=prerelease` instead.
TriggerContext resolveTriggerContext(String currentBranch) {
  if (packageNameFromPatchBranch(currentBranch) != null) {
    return TriggerContext.patch;
  }
  return TriggerContext.mainline;
}

/// The `{major}.{minor}` release line a patch branch is confined to. Only
/// called once [_resolveGroups] has validated the branch matches the
/// convention, so a non-match here would be a bug in that validation.
(int major, int minor) _releaseLineFromPatchBranch(String branch) {
  final match = _patchBranchPattern.firstMatch(branch)!;
  return (
    int.parse(match.namedGroup('major')!),
    int.parse(match.namedGroup('minor')!),
  );
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

  if (!ctx.includeFederated) {
    return all.where((pkg) => requested.contains(pkg.name)).toList();
  }

  final groupKeys = groups
      .where(
        (group) => group.members.any((pkg) => requested.contains(pkg.name)),
      )
      .map((group) => group.key)
      .toSet();

  return all.where((pkg) => groupKeys.contains(pkg.groupKey)).toList();
}
