// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

/// Whether [pubspecFile] declares a top-level `dependency_overrides:` key.
///
/// A real, publishable package's `pubspec.yaml` should never carry a
/// committed override -- this repo's actual local-dev-linking mechanism
/// is melos-managed `pubspec_overrides.yaml`, which is gitignored and
/// never present in a fresh checkout, so there's nothing for release-prep
/// to strip there. This is a fail-loud guard for the case where one ended
/// up committed anyway -- `pub.dev` refuses to publish a package with any
/// `dependency_overrides` present.
bool pubspecHasDependencyOverrides(File pubspecFile) {
  if (!pubspecFile.existsSync()) return false;
  return pubspecFile.readAsLinesSync().any(
    (line) => line == 'dependency_overrides:',
  );
}
