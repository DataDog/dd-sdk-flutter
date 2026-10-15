// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:version/version.dart';
import 'package:yaml/yaml.dart';

/// Generates or checks the shipped Flags version from its package manifest.
/// Other packages retain their existing version-generation behavior.
bool syncFlagsVersion(String packageRoot, Logger logger, {bool check = false}) {
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
    // Keep the manifest string, including prerelease and build metadata.
    final contents =
        '''// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// Generated from pubspec.yaml by the release tool. Do not edit.
const ddPackageVersion = '$version';
''';
    final output = File(path.join(packageRoot, 'lib/src/version.dart'));
    if (check) {
      if (!output.existsSync() || output.readAsStringSync() != contents) {
        throw StateError('Flags version.dart is missing or stale. '
            'Run the release version update before packaging.');
      }
    } else {
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(contents);
    }
    return true;
  } catch (error) {
    logger.severe('Cannot validate or generate Flags package version: $error');
    return false;
  }
}
