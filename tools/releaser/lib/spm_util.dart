// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import 'dart:io';

import 'package:logging/logging.dart';

import 'helpers.dart';

/// Matches a `Package.swift` dd-sdk-ios dependency line, capturing the parts
/// kept when its version argument is rewritten.
final _iosSpmDependencyRewritePattern = RegExp(
  r'^(?<indent>\s*)(?<prefix>\.package\(url:\s*"[^"]*dd-sdk-ios[^"]*",\s*)(?<versionArg>[^)]+)(?<suffix>\).*)',
  caseSensitive: false,
);

/// Rewrites [packageSwiftFile]'s dd-sdk-ios dependency line to pin at
/// [targetVersion] via an `exact:` constraint.
Future<void> pinIosSpmVersion(
  File packageSwiftFile,
  String targetVersion,
  Logger logger,
  bool dryRun,
) => setIosSpmVersionArgument(
  packageSwiftFile,
  'exact: "$targetVersion"',
  logger,
  dryRun,
);

/// Rewrites [packageSwiftFile]'s dd-sdk-ios dependency line to use
/// [versionArgument] (e.g. `exact: "3.16.0"` or `branch: "develop"`).
Future<void> setIosSpmVersionArgument(
  File packageSwiftFile,
  String versionArgument,
  Logger logger,
  bool dryRun,
) async {
  logger.info(
    'ℹ️ Setting dd-sdk-ios to $versionArgument in ${packageSwiftFile.path}',
  );

  await transformFile(packageSwiftFile, logger, dryRun, (line) {
    final match = _iosSpmDependencyRewritePattern.firstMatch(line);
    if (match == null) return line;
    return '${match.namedGroup('indent')}${match.namedGroup('prefix')}'
        '$versionArgument${match.namedGroup('suffix')}';
  });
}
