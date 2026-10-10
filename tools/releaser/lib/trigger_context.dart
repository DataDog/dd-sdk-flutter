// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

/// Which of the three GitLab trigger contexts a run is happening under:
/// mainline (`develop`), patch (a standing `release/{package}/vX.Y.x`
/// branch), or pre-release (a whitelisted long-lived branch like `v4`).
///
/// Lives in its own file (rather than alongside `release_plan.dart`, its
/// only real "owner") because `native_sdk.dart` also needs it, and
/// `release_plan.dart` in turn needs types from `native_sdk.dart` --
/// putting the enum in either file would create a cyclic import between
/// the two.
enum TriggerContext {
  mainline,
  patch,
  preRelease;

  static TriggerContext? parse(String raw) {
    switch (raw.toLowerCase()) {
      case 'mainline':
        return TriggerContext.mainline;
      case 'patch':
        return TriggerContext.patch;
      case 'prerelease':
        return TriggerContext.preRelease;
      default:
        return null;
    }
  }
}
