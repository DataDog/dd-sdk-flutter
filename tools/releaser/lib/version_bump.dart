// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

/// The semver bump a release applies.
///
/// Deliberately separate from the identically-named enum in
/// `version_updater.dart`. That one belongs to the legacy `releaser` CLI,
/// still carries a `rev` variant, and is scheduled for deletion once
/// `prepare_release.dart` replaces that pipeline. Sharing it would couple the
/// release-plan module to code on its way out; a duplicated enum until then
/// is the cheaper side of that trade.
enum VersionBumpType {
  patch(severity: 0),
  minor(severity: 1),
  major(severity: 2),
  // Not part of the major/minor/patch severity ordering below -- assigned
  // directly from a prerelease label/counter, never derived by comparing
  // against another bump level.
  prerelease(severity: -1);

  /// Where this bump ranks against another major/minor/patch bump (higher
  /// wins). Meaningless for [prerelease], which is never compared this way.
  final int severity;

  const VersionBumpType({required this.severity});

  /// Parses a `BUMP_TYPE` per-run override -- major/minor/patch only, or
  /// null for "no override given" (a null or empty [raw]). `prerelease`
  /// isn't a valid override; that path is driven by `PRERELEASE_LABEL` on
  /// a pre-release branch instead. Throws rather than silently falling
  /// back on anything unrecognized, so a typo'd `BUMP_TYPE` fails the run
  /// rather than quietly becoming a patch bump.
  static VersionBumpType? parseOverride(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    switch (raw) {
      case 'major':
        return VersionBumpType.major;
      case 'minor':
        return VersionBumpType.minor;
      case 'patch':
        return VersionBumpType.patch;
      default:
        throw StateError('BUMP_TYPE "$raw" is not one of major, minor, patch.');
    }
  }
}
