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
import 'git/git_history.dart';
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

  /// The last release *on the line being released* -- or `pubspec.yaml`'s
  /// version for a package that has never been published.
  ///
  /// Read from pub.dev rather than `pubspec.yaml` for anything published:
  /// old releases ended by bumping pubspec to a "next potential" version that
  /// doesn't exist, so pubspec routinely names something never shipped
  /// (`3.6.0` while `3.5.0` is the newest release).
  ///
  /// Scoped to the line rather than "newest published anywhere", because
  /// release branches never merge back and the lines are disjoint: rendering
  /// `3.0.0 -> 2.1.3` for a patch of the `2.1.x` line names a version from a
  /// branch this release has nothing to do with.
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
  final gateways = nativeSdkGateways ?? GithubSdkGateways.forRepo(ctx.repoRoot);

  final groups = await _resolveGroups(ctx);
  final selected = _selectPackages(groups, ctx);

  // Collected across every package so an `--all` run reports every stale pubspec
  // at once instead of dying on the first.
  final targetConflicts = <String>[];

  final plans = <PackagePlan>[];
  for (final pkg in selected) {
    final plan = await _computePackagePlan(
      pkg,
      ctx,
      resolvedGitDir,
      gateways,
      await published(pkg.name),
      isExplicitlyRequested: ctx.requestedPackages.contains(pkg.name),
      targetConflicts: targetConflicts,
    );
    if (plan != null) plans.add(plan);
  }

  if (targetConflicts.isNotEmpty) {
    throw StateError(
      'Pre-release target${targetConflicts.length == 1 ? '' : 's'} not ahead '
      'of what pub.dev already has:\n\n'
      '${targetConflicts.map((c) => '  - $c').join('\n\n')}',
    );
  }

  return ReleasePlan(trigger: ctx.trigger, packages: plans);
}

/// [NativeSdkGateways] backed by real `gh` calls.
///
/// A thin adapter with no state of its own -- [github] does the remembering,
/// caching each repo's release list and each resolved ref for its own
/// lifetime. One wrapper per run therefore means the same "latest
/// dd-sdk-ios release" question costs one call, not one per package: all six
/// members of a federated group share the answer.
class GithubSdkGateways extends NativeSdkGateways {
  final GithubCommandWrapper github;
  final Logger logger;

  GithubSdkGateways(this.github, {Logger? logger}) : logger = logger ?? _log;

  GithubSdkGateways.forRepo(String repoRoot, {Logger? logger})
    : this(GithubCommandWrapper(repoRoot), logger: logger);

  @override
  Future<String> fetchLatest(String repoSlug) async =>
      (await github.getLatestRelease(logger, repoSlug)).tagName;

  @override
  Future<String> resolveCommitSha(String repoSlug, String ref) =>
      github.getCommitSha(logger, repoSlug, ref);

  @override
  Future<bool> releaseExists(String repoSlug, String version) async =>
      await github.getReleaseByTagName(logger, repoSlug, version) != null;
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
        'version comes from the prerelease counter against the target the '
        'package declares in its pubspec.yaml. Edit that version to move the '
        'line, or use PRERELEASE_LABEL to start a new label.',
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
  required List<String> targetConflicts,
}) async {
  // Two questions, answered separately because on a pre-release line they
  // have different answers:
  //
  //   versionBase -- what the new version is derived from.
  //   commitBase  -- the last release *on the line being released*: what
  //                  "since we last shipped" means, for the changelog range,
  //                  for whether this package ships at all, and for what the
  //                  native SDK pins are compared against.
  //
  // They coincide on mainline (a stable release supersedes the whole line)
  // and on a patch branch (confined to its own line), and diverge on a
  // pre-release, whose version comes from pubspec while its changelog still
  // runs from the previous beta.
  //
  // commitBase is deliberately not `published.latest`. Release branches never
  // merge back, so release lines are disjoint: on a `2.1.x` patch branch a
  // published `3.0.0` lives on a branch with no relationship to this one, and
  // its pins describe nothing about what this line last shipped.
  final Version? versionBase;
  final Version? commitBase;
  final warnings = <String>[];

  final files = resolveNativeDependencyFiles(pkg.absolutePath(ctx.repoRoot));

  // See [_nativeSdkEligibleGroupKey]. Non-eligible packages' files are
  // still discovered, for [_nativeDependencyChanges] below.
  final isNativeSdkEligible = pkg.groupKey == _nativeSdkEligibleGroupKey;

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
      final target = declaredPrereleaseTarget(pkg);
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

  // Memoized because a pre-release asks for two ranges -- since the previous
  // beta for the changelog, since the last stable for the advisory -- and on
  // a first beta those are the same baseline. Walking twice would also emit
  // the missing-tag warning twice.
  final commitsByBaseline = <Version?, List<ConventionalCommit>>{};
  Future<List<ConventionalCommit>> commitsSince(Version? baseline) async {
    final cached = commitsByBaseline[baseline];
    if (cached != null) return cached;

    final (sinceSha, rangeWarnings) = await _commitRangeStart(
      gitDir,
      pkg.name,
      published,
      baseline,
    );
    for (final warning in rangeWarnings) {
      if (!warnings.contains(warning)) warnings.add(warning);
    }
    return commitsByBaseline[baseline] = await _conventionalCommitsSince(
      gitDir,
      pathspec: pkg.relativePath,
      sinceSha: sinceSha,
    );
  }

  final commits = await commitsSince(commitBase);

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

  // Deliberately after the eligibility gate: a package that isn't shipping
  // this run has no target to conflict with, and letting an untouched sibling
  // fail an `--all` run is the exact thing the gate exists to prevent.
  if (ctx.trigger == TriggerContext.preRelease) {
    final conflict = _prereleaseTargetConflict(pkg, versionBase!, published);
    if (conflict != null) {
      targetConflicts.add(conflict);
      return null;
    }
  }

  final nativeSdkDeltas = isNativeSdkEligible
      ? await _computeNativeSdkDeltas(
          pkg,
          files,
          ctx,
          gitDir,
          commitBase,
          gateways,
          warnings,
        )
      : const <NativeSdkDelta>[];

  final nativeDependencyChanges = isNativeSdkEligible
      ? const <NativeDependencyChange>[]
      : await _nativeDependencyChanges(pkg, files, ctx, gitDir, published);

  // The line's own last release, not the newest published anywhere -- see the
  // commitBase note above. Rendering "3.0.0 -> 2.1.3" for a patch of the
  // 2.1.x line names a version from a branch this release has nothing to do
  // with.
  final currentVersion = commitBase?.toString() ?? pkg.version;

  if (ctx.trigger == TriggerContext.preRelease) {
    final advisory = _prereleaseTargetAdvisory(
      pkg: pkg,
      target: versionBase!,
      latestStable: published.latestStable,
      commitsSinceStable: await commitsSince(published.latestStable),
      nativeSdkDeltas: nativeSdkDeltas,
    );
    if (advisory != null) warnings.add(advisory);
  }

  return switch (ctx.trigger) {
    TriggerContext.patch => _computePatchPlan(
      pkg,
      currentVersion,
      commits,
      // Non-null on this path: the patch arm of the switch above throws
      // rather than leaving a branch with no release to patch.
      versionBase!,
      nativeSdkDeltas,
      nativeDependencyChanges,
      warnings,
    ),
    TriggerContext.preRelease => _computePrereleasePlan(
      pkg,
      ctx,
      currentVersion,
      commits,
      // Non-null on this path: declaredPrereleaseTarget always returns one.
      versionBase!,
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

/// The version a pre-release line is working towards, as declared in the
/// package's own `pubspec.yaml`.
///
/// Declared, not computed. A computed target has to be re-derived on every
/// run, from a baseline that moves as the line progresses -- which means every
/// signal feeding it must be measured since the last *stable* release or the
/// target silently regresses (`4.0.0-beta.1`, then `3.5.1-beta.1` once a prior
/// beta has already absorbed the evidence). That invariant is invisible at the
/// call site and was broken twice. A declared target cannot regress.
///
/// Any pre-release suffix and build metadata are stripped: after
/// `4.0.0-beta.1` ships, the content commit leaves pubspec reading
/// `4.0.0-beta.1`, and that is still a declaration of `4.0.0`. This matches
/// [PublishedVersions.prereleasesAt], which ignores the target's own suffix
/// for the same reason.
///
/// The objection this design has to answer -- that pubspec is a second source
/// of truth free to disagree with what has shipped -- is handled by
/// [_prereleaseTargetConflict], which refuses a target that isn't ahead of
/// pub.dev, and by [_prereleaseTargetAdvisory], which flags a target the
/// commits say is too low.
Version declaredPrereleaseTarget(DiscoveredPackage pkg) {
  final declared = Version.parse(pkg.version);
  return Version(declared.major, declared.minor, declared.patch);
}

/// Why [target] can't be released as a pre-release, or null if it can.
///
/// Returned rather than thrown so `computeReleasePlan` can preflight every
/// selected package and report all of them at once: on an `--all` or
/// `--include-federated` run, throwing from inside the per-package loop would
/// kill the whole plan over a sibling nobody asked for.
String? _prereleaseTargetConflict(
  DiscoveredPackage pkg,
  Version target,
  PublishedVersions published,
) {
  if (published.hasStableAt(target)) {
    return '${pkg.name}: pubspec.yaml declares $target, which has already '
        'been released stably. A pre-release against it would sort below the '
        'published version -- bump pubspec.yaml to the version this '
        'pre-release line is working towards.';
  }

  // Explicit null check rather than `target <= latestStable`: package:version's
  // `<=` takes a dynamic and quietly returns false against null, so the
  // shorter form would fail open for a never-published package.
  final stable = published.latestStable;
  if (stable != null && target <= stable) {
    return '${pkg.name}: pubspec.yaml declares $target, but $stable is '
        'already published. A pre-release has to work towards something newer '
        '-- bump pubspec.yaml to the version this pre-release line is working '
        'towards.';
  }

  return null;
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
  Version versionBase,
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

  // The same rejection, for the other way a change of that size can arrive.
  // A patch branch's pins are left alone by default, so this is only
  // reachable through an explicit override -- someone asking to jump the
  // native SDK a minor or major on a line that can only ship patches.
  for (final delta in nativeSdkDeltas) {
    final bump = delta.getImpliedBump();
    if (bump == VersionBumpType.major || bump == VersionBumpType.minor) {
      throw StateError(
        '${delta.sdk.displayName} SDK ${delta.currentDeclaration} -> '
        '${delta.targetVersion} is a ${bump!.name} change, which does not '
        'belong on a patch branch (only fixes are allowed here). Release it '
        'from develop instead, or pick a patch-level version of the SDK.',
      );
    }
  }

  return PackagePlan(
    package: pkg,
    currentVersion: currentVersion,
    newVersion: versionBase.incrementPatch().toString(),
    bumpLevel: VersionBumpType.patch,
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
      _impliedBump(
        commits: commits,
        nativeSdkDeltas: nativeSdkDeltas,
        bumpTypeOverride: ctx.bumpTypeOverride,
      ) ??
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

/// A pre-release is its declared target plus a counter: `4.0.0` from
/// [declaredPrereleaseTarget], then `-beta.1`, `-beta.2`, and so on.
///
/// The target being declared rather than computed is what keeps the base
/// still while the line progresses -- see [declaredPrereleaseTarget] for why
/// a computed one couldn't be. Everything decided here is about the suffix.
PackagePlan _computePrereleasePlan(
  DiscoveredPackage pkg,
  RunContext ctx,
  String currentVersion,
  List<ConventionalCommit> commits,
  Version target,
  PublishedVersions published,
  List<NativeSdkDelta> nativeSdkDeltas,
  List<NativeDependencyChange> nativeDependencyChanges,
  List<String> warnings,
) {
  final counter = published.prereleasesAt(target).lastOrNull;
  final label = ctx.prereleaseLabel;

  // A target already released stably was rejected by
  // _prereleaseTargetConflict before this point, so there's no such case to
  // handle here.
  final Version newVersion;
  if (counter != null && (label == null || counter.preRelease.first == label)) {
    newVersion = counter.incrementPreRelease();
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

  // Sorting below something already published is legitimate when another line
  // is shipping concurrently (`4.0.0-beta.2` while `5.0.0-alpha.1` exists),
  // so this can't be the error the invariant above is -- but it's also what a
  // pubspec left behind looks like, and that's worth saying out loud.
  final newestPublished = published.latest;
  if (newestPublished != null && newVersion < newestPublished) {
    warnings.add(
      '${pkg.name}: $newVersion sorts below the published $newestPublished. '
      'Expected if another release line is shipping concurrently; otherwise '
      'pubspec.yaml is behind what has already gone out.',
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

/// The bump the evidence implies, independent of how any target is chosen --
/// null when nothing carries semver weight.
///
/// A native SDK's own bump carries through even without a qualifying commit
/// of the wrapper package's own: a dd-sdk-ios minor release pinned here is
/// itself a minor change for whoever depends on this package. An explicit
/// `BUMP_TYPE` wins outright, since that's a human's direct instruction.
///
/// One function rather than one per caller: mainline uses it to pick the
/// version, and [_prereleaseTargetAdvisory] uses it to sanity-check a
/// declared one. Keeping them separate is how the native SDK signal came to
/// be wired into the first and not the second.
VersionBumpType? _impliedBump({
  required List<ConventionalCommit> commits,
  required List<NativeSdkDelta> nativeSdkDeltas,
  String? bumpTypeOverride,
}) =>
    VersionBumpType.parseOverride(bumpTypeOverride) ??
    highestBump([
      aggregateBumpLevel(commits),
      nativeSdkAggregateBump(nativeSdkDeltas),
    ]);

/// A warning when the pre-release target declared in pubspec sits *below*
/// what the evidence implies -- null when there's nothing to say.
///
/// Deliberately one-directional. Declaring a target ahead of the commits is
/// the whole point of declaring one (the `v4` line targets `4.0.0` from its
/// first beta, long before every breaking change has landed), so warning on
/// that would fire on every run. Worse, commits here are pathspec-scoped, so
/// a breaking change living in `_platform_interface` is invisible to
/// `datadog_flutter_plugin` -- a symmetric check would cry wolf on the
/// flagship group forever.
///
/// A target that's too *low* is the real hazard: a `feat!:` landed and the
/// line is about to ship `4.0.1-beta.3` as though nothing broke.
String? _prereleaseTargetAdvisory({
  required DiscoveredPackage pkg,
  required Version target,
  required Version? latestStable,
  required List<ConventionalCommit> commitsSinceStable,
  required List<NativeSdkDelta> nativeSdkDeltas,
}) {
  // Nothing to measure from: never published, or published only as
  // pre-releases. Bumping a base that doesn't exist would invent a comparison.
  if (latestStable == null) return null;

  final implied = _impliedBump(
    commits: commitsSinceStable,
    nativeSdkDeltas: nativeSdkDeltas,
  );
  if (implied == null) return null;

  final impliedTarget = _applyBump(latestStable, implied);
  if (impliedTarget <= target) return null;

  final reason = commitsSinceStable.firstWhereOrNull(
    (c) => c.bumpType == implied,
  );

  return '${pkg.name}: pubspec.yaml targets $target, but changes since '
      '$latestStable imply $impliedTarget'
      '${reason == null ? '' : ' (${reason.type}: ${reason.description})'}. '
      'Shipping $target as declared -- bump pubspec.yaml if that is wrong.';
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

/// [file]'s content as it existed at [atVersion] in [pkg]'s git history, or
/// null if [atVersion] is null, no tag resolves for it (see [tagSha]), or
/// [file] didn't exist at that commit.
Future<String?> _publishedContentAt(
  DiscoveredPackage pkg,
  Version? atVersion,
  RunContext ctx,
  GitDir gitDir,
  File? file,
) async {
  if (atVersion == null || file == null) return null;
  return fileContentAtRef(
    gitDir,
    '${pkg.name}/v$atVersion',
    p.relative(file.path, from: ctx.repoRoot),
  );
}

/// One [NativeSdkDelta] per SDK [pkg] ships a manifest for, comparing each
/// SDK's resolved target against what that manifest declared at [baseline] --
/// the last release *on the line being released*, i.e. `commitBase`. Release
/// branches never merge back, so a version from another line's tag describes
/// nothing about this one.
///
/// Two declarations are read per SDK, and they answer different questions:
/// the one at [baseline] is what the line last shipped (the bump comparison),
/// and the one in the working tree is what someone has asked for now (a pin
/// means hold -- see [resolveNativeSdkTarget]).
///
/// Appends to [warnings] when a pin is honoured, and when the baseline
/// declaration can't be read as a version.
Future<List<NativeSdkDelta>> _computeNativeSdkDeltas(
  DiscoveredPackage pkg,
  NativeDependencyFiles files,
  RunContext ctx,
  GitDir gitDir,
  Version? baseline,
  NativeSdkGateways gateways,
  List<String> warnings,
) async {
  Future<String?> historicalContent(File? file) =>
      _publishedContentAt(pkg, baseline, ctx, gitDir, file);

  String? workingTreeContent(File? file) => file?.readAsStringSync();

  final perSdkFiles = {
    NativeSdk.ios: (
      files: [?files.iosPodspec, ?files.iosSpmManifest],
      override: ctx.iosSdkVersionOverride,
      current: currentIosDeclaration(
        podspecContent: await historicalContent(files.iosPodspec),
        spmContent: await historicalContent(files.iosSpmManifest),
      ),
      declared: currentIosDeclaration(
        podspecContent: workingTreeContent(files.iosPodspec),
        spmContent: workingTreeContent(files.iosSpmManifest),
      ),
    ),
    NativeSdk.android: (
      files: [?files.androidGradle],
      override: ctx.androidSdkVersionOverride,
      current: currentAndroidDeclaration(
        await historicalContent(files.androidGradle),
      ),
      declared: currentAndroidDeclaration(
        workingTreeContent(files.androidGradle),
      ),
    ),
    NativeSdk.cpp: (
      files: files.cppCMakeLists,
      override: ctx.cppVersionOverride,
      current: currentCppDeclaration(
        await historicalContent(files.cppCMakeLists.firstOrNull),
      ),
      declared: currentCppDeclaration(
        workingTreeContent(files.cppCMakeLists.firstOrNull),
      ),
    ),
  };

  final deltas = <NativeSdkDelta>[];
  for (final MapEntry(key: sdk, value: (:files, :override, :current, :declared))
      in perSdkFiles.entries) {
    if (files.isEmpty) continue;

    final target = await resolveNativeSdkTarget(
      trigger: ctx.trigger,
      override: override,
      workingTreeDeclaration: declared,
      fetchLatest: () => gateways.fetchLatest(sdk.repoSlug),
      releaseExists: (version) => gateways.releaseExists(sdk.repoSlug, version),
      onPinned: (pin) => warnings.add(
        '${sdk.displayName} SDK is pinned at $pin in ${pkg.name}\'s manifest '
        '-- honouring the pin and not checking for a newer release. Remove '
        'the pin to resume tracking the latest, or pass an explicit override '
        'to move it.',
      ),
    );

    // A baseline we can't read costs both the bump signal and the changelog
    // section, so say so rather than silently contributing nothing. Only
    // reachable for tags predating the current tooling (an Android `3+`, a
    // hand-pinned GIT_TAG SHA with no `# vX.Y.Z` annotation) -- every tag it
    // cuts carries a complete version.
    if (target != null &&
        current != null &&
        normalizeVersion(current) == null) {
      warnings.add(
        '${sdk.displayName} SDK: ${pkg.name}\'s last release on this line '
        'declared "$current", which is not a complete version -- it adds no '
        'bump signal and has no changelog section this run.',
      );
    }

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
      _publishedContentAt(pkg, latest, ctx, gitDir, file);

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

/// [commitsSince]'s raw records, parsed into [ConventionalCommit]s and
/// narrowed to the ones that carry semver weight -- commits that fail to
/// parse, or parse but don't bump anything (`chore:`, `docs:`, etc.), are
/// dropped since nothing here cares about them either as bump input or as a
/// [PackagePlan.contributingCommits] entry.
Future<List<ConventionalCommit>> _conventionalCommitsSince(
  GitDir gitDir, {
  required String pathspec,
  String? sinceSha,
}) async {
  final records = await commitsSince(
    gitDir,
    pathspec: pathspec,
    sinceSha: sinceSha,
  );
  return records
      .map((r) => ConventionalCommit.parse(r.message, sha: r.sha))
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
