// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:version/version.dart';
import 'package:yaml/yaml.dart';

/// Checks the Flags reporting constant against the version being published.
/// Other packages keep their existing release checks.
bool validateFlagsVersion(String packageRoot, Logger logger) {
  try {
    final manifest = loadYaml(
      File(path.join(packageRoot, 'pubspec.yaml')).readAsStringSync(),
    ) as YamlMap;
    if (manifest['name'] != 'datadog_flags') return true;

    final version = manifest['version'];
    if (version is! String) {
      throw const FormatException('Flags package version must be a string');
    }
    Version.parse(version);
    final source =
        File(path.join(packageRoot, 'lib/src/version.dart')).readAsStringSync();
    final declarations = RegExp(
      r'''^const ddPackageVersion = ['"]([^'"]+)['"];\s*$''',
      multiLine: true,
    ).allMatches(source);
    if (declarations.length != 1 || declarations.single.group(1) != version) {
      throw StateError('Flags version.dart does not match pubspec.yaml. '
          'Run the release version update before publishing.');
    }
    return true;
  } catch (error) {
    logger.severe('Cannot validate Flags reporting version: $error');
    return false;
  }
}
