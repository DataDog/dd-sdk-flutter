// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'command.dart';
import 'helpers.dart';

class RemoveDependencyOverridesCommand extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    final pubspecFile = File(path.join(args.packageRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      logger.shout('⁉️ Could not find pubspec.yaml at ${pubspecFile.path}');
      return false;
    }
    logger.info('🔀 Removing dependency_overrides from ${pubspecFile.path}');

    var inDependencyOverrides = false;
    await transformFile(pubspecFile, logger, args.dryRun, (element) {
      if (inDependencyOverrides) {
        // If the line isn't empty and starts with characters, we're in a new section
        if (element.isNotEmpty && element.startsWith(RegExp(r'\S+'))) {
          logger.fine('Turning off dependency_overrides on line:\n$element');
          inDependencyOverrides = false;
        }
      } else if (element == 'dependency_overrides:') {
        inDependencyOverrides = true;
      }

      return inDependencyOverrides ? null : element;
    });

    return true;
  }
}
