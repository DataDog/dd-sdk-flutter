// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'command.dart';
import 'helpers.dart';

const datadogIosRepo = 'https://github.com/Datadog/dd-sdk-ios.git';
final packageDependencyPattern = RegExp(
  r'\s+\.package\(url\: "(?<package>.+)", .+\)',
);

class PinSwiftPackageVersion extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    // Other packages can keep looser version constraints
    final corePacakge = args.packages
        .firstWhereOrNull((e) => e.name == 'datadog_flutter_plugin');
    if (corePacakge != null) {
      if (!await _pinSpmVersion(args, corePacakge, logger)) {
        return false;
      }
    }

    return true;
  }

  Future<bool> _pinSpmVersion(
      CommandArguments args, PackageRelease package, Logger logger) {
    return pinSpmVersion(
      args.gitDir.path,
      package.name,
      'exact: "${args.iOSRelease}"',
      args.dryRun,
      logger,
    );
  }

  static Future<bool> pinSpmVersion(
    String rootPath,
    String packageName,
    String versionString,
    bool dryRun,
    Logger logger,
  ) async {
    final packageLocation = 'ios/$packageName/Package.swift';

    final file = File(
      path.join(rootPath, 'packages/$packageName', packageLocation),
    );

    if (!file.existsSync()) {
      logger.warning(
        '⚠️ Could not find file $file. This is expected for non-core packages',
      );
      return true;
    }

    logger.info('ℹ️ Setting the iOS Pod Dependency to $versionString');
    await transformFile(file, logger, dryRun, (line) {
      final match = packageDependencyPattern.firstMatch(line);
      if (match != null && match.namedGroup('package') == datadogIosRepo) {
        final needsComma = line.trimRight().endsWith(',');
        line =
            '        .package(url: "$datadogIosRepo", $versionString)${needsComma ? ',' : ''}';
      }
      return line;
    });

    return true;
  }
}
