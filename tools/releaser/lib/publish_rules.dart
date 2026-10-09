// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'release_plan.dart' show packageNameFromPatchBranch;

// Pure decision logic for the release tooling, kept in `lib/` so it's
// importable and directly testable -- same split as the rest of this package
// (business logic in `lib/`, thin orchestration in `bin/`).

/// Whether [sourceBranch] is a standing support branch: a patch line such as
/// `release/datadog_dio/v2.2.x`, or a major line such as
/// `release/datadog_dio/v3.x`.
bool isSupportBranch(String sourceBranch) =>
    packageNameFromPatchBranch(sourceBranch) != null;

/// The only package whose GitHub Release is ever allowed to claim
/// `--latest`. See [shouldMarkReleaseLatest].
const mainPackage = 'datadog_flutter_plugin';

/// Whether a `gh release create` for [package] should pass `--latest`
/// rather than `--latest=false`.
///
/// "Latest release" is a repo-wide GitHub concept, not a per-package one --
/// with ~15 packages releasing into the same repo, only [mainPackage]
/// should ever claim it. A patch on an old minor line, or a pre-release,
/// also never should, regardless of package.
bool shouldMarkReleaseLatest({
  required String package,
  required bool prerelease,
  required bool isSupport,
}) => package == mainPackage && !prerelease && !isSupport;

/// The whitelisted pre-release branches, each paired with a disposable
/// `<branch>-main` publish target. Add an entry when a major pre-release
/// effort opens and remove it when the effort ships; keep it in sync with
/// `prepare-release`'s rules in `.gitlab-ci.yml` and the `self.*.sts.yaml`
/// trust policies.
const preReleaseBranches = ['v4'];

/// The branch the release-prep PR for a `prepare-release` run on
/// [sourceBranch] merges into: `main` for `develop`, `<branch>-main` for a
/// whitelisted pre-release branch, and a support branch merges into itself.
///
/// Returns `null` for a branch this mapping doesn't recognize, which the
/// caller should treat as a rejection, not a pass-through.
String? expectedIntegrationBranch(String sourceBranch) {
  if (sourceBranch == 'develop') return 'main';
  if (preReleaseBranches.contains(sourceBranch)) return '$sourceBranch-main';
  if (isSupportBranch(sourceBranch)) return sourceBranch;
  return null;
}

/// The inverse of [expectedIntegrationBranch]: the `prepare-release` source
/// branch (`develop`/a pre-release branch/that same support branch) whose release-prep PR
/// merges into [integrationBranch] (`main`/`v4-main`/a support branch). Phase 2
/// backports commit A into that source branch.
///
/// Throws for anything else, same as [expectedIntegrationBranch] returning
/// `null` -- `publish_release.dart` calls this with a merged PR's base ref,
/// so an unrecognized base has to be a loud rejection, not a silent
/// pass-through.
String sourceBranchFor(String integrationBranch) {
  if (integrationBranch == 'main') return 'develop';
  for (final branch in preReleaseBranches) {
    if (integrationBranch == '$branch-main') return branch;
  }
  if (isSupportBranch(integrationBranch)) return integrationBranch;
  throw StateError(
    '"$integrationBranch" is not a recognized release integration branch '
    '(main, a whitelisted pre-release `-main`, or a support branch).',
  );
}
