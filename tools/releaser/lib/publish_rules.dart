// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

final _patchBranchPattern = RegExp(r'^release/.+/v\d+\.\d+\.x$');

/// Pure decision logic `publish_release.dart` needs, pulled out of that
/// `bin/` entry point so it's importable and directly testable -- same
/// split as the rest of this package (business logic in `lib/`, thin
/// orchestration in `bin/`).
///
/// Whether [sourceBranch] (a [ManifestPackageEntry.sourceBranch] value) is a
/// standing patch-release branch, e.g. `release/datadog_dio/v2.2.x`.
bool isPatchReleaseBranch(String sourceBranch) =>
    _patchBranchPattern.hasMatch(sourceBranch);

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

/// Given a [ManifestPackageEntry.sourceBranch] value (the branch this run's
/// `prepare-release` job originally ran on), the branch the resulting
/// release-prep PR actually merges into -- i.e. what the `release-trigger/*`
/// tagged commit must be reachable from for `publish_release.dart`'s
/// authenticity check to accept it. Mirrors the same branch whitelist as
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
