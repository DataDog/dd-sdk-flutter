// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:version/version.dart';

import 'release_plan.dart' show packageNameFromPatchBranch;

// Pure decision logic for the release tooling, kept in `lib/` so it's
// importable and directly testable -- same split as the rest of this package
// (business logic in `lib/`, thin orchestration in `bin/`).

/// Whether [sourceBranch] is a standing support branch: a patch line such as
/// `release/datadog_dio/v2.2.x`, or a major line such as
/// `release/datadog_dio/v3.x`.
bool isPatchReleaseBranch(String sourceBranch) =>
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
  required bool isPatch,
}) => package == mainPackage && !prerelease && !isPatch;

/// The branch the release-prep PR for a `prepare-release` run on
/// [sourceBranch] merges into. Mirrors the same branch whitelist as
/// `push-release-trigger-tag`'s `rules:` in `.gitlab-ci.yml` and
/// `self.tag-push.sts.yaml`'s `claim_pattern` -- keep all three in sync.
///
/// Returns `null` for a branch this mapping doesn't recognize, which the
/// caller should treat as a rejection, not a pass-through.
String? expectedIntegrationBranch(String sourceBranch) {
  if (sourceBranch == 'develop') return 'main';
  if (sourceBranch == 'v4') return 'v4-main';
  if (isPatchReleaseBranch(sourceBranch)) return sourceBranch;
  return null;
}

/// The inverse of [expectedIntegrationBranch]: the `prepare-release` source
/// branch (`develop`/`v4`/that same support branch) whose release-prep PR
/// merges into [integrationBranch] (`main`/`v4-main`/a support branch). Phase 2
/// backports commit A into that source branch.
///
/// Throws for anything else, same as [expectedIntegrationBranch] returning
/// `null` -- `publish_release.dart` calls this with a merged PR's base ref,
/// so an unrecognized base has to be a loud rejection, not a silent
/// pass-through.
String sourceBranchFor(String integrationBranch) {
  if (integrationBranch == 'main') return 'develop';
  if (integrationBranch == 'v4-main') return 'v4';
  if (isPatchReleaseBranch(integrationBranch)) return integrationBranch;
  throw StateError(
    '"$integrationBranch" is not a recognized release integration branch '
    '(main, v4-main, or a support branch).',
  );
}

/// The support branch a support-branch release's [bump] implies for
/// [package] at [toVersion]: a `patch` release comes from its exact
/// `{major}.{minor}` line's branch, and a `minor` release from the
/// `{major}` line's branch. Patches never ship from a major-line branch.
///
/// Throws for any other [bump] (`major`/`prerelease`/`first release`),
/// none of which a support branch should ever produce.
String expectedPatchBranchFor({
  required String package,
  required String toVersion,
  required String bump,
}) {
  final version = Version.parse(toVersion);
  switch (bump) {
    case 'patch':
      return 'release/$package/v${version.major}.${version.minor}.x';
    case 'minor':
      return 'release/$package/v${version.major}.x';
    default:
      throw StateError(
        '"$bump" is not a bump a support branch should produce '
        '(expected patch or minor).',
      );
  }
}
