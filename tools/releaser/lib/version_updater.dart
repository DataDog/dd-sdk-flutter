// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'command.dart';

class UpdateVersionsCommand extends Command {
  final versionCapture = RegExp(r'^version\: (?<version>.*)');

  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    if (!await _updatePackagePubspec(
        args.packageRoot, args.version, logger, args.dryRun)) {
      return false;
    }

    if (!await _updateVersionDartFile(
        args.packageRoot, args.version, logger, args.dryRun)) {
      return false;
    }

    if (!await _updateChangelog(
        args.packageRoot, args.version, logger, args.dryRun)) {
      return false;
    }
    return true;
  }

  Future<void> _transformFile(
    File file,
    Logger logger,
    bool dryRun,
    String Function(String e) transformer,
  ) async {
    final newFileBuffer = StringBuffer();
    await file
        .openRead()
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .forEach((element) {
      final newValue = transformer(element);
      newFileBuffer.writeln(newValue);
    });

    final filename = path.basename(file.path);
    logger.finest(' ------- NEW  $filename CONTENTS ------');
    logger.finest(newFileBuffer.toString());
    if (!dryRun) {
      file.openWrite().write(newFileBuffer);
      logger.info(' ✏️ Wrote ${file.path}');
    }
  }

  Future<bool> _updatePackagePubspec(
      String packageRoot, String version, Logger logger, bool dryRun) async {
    final pubspecFile = File(path.join(packageRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      logger.shout('⁉️ Could not find pubspec.yaml at ${pubspecFile.path}');
      return false;
    }

    await _transformFile(pubspecFile, logger, dryRun, (element) {
      final match = versionCapture.firstMatch(element);
      if (match != null) {
        final oldVersion = match.namedGroup('version');
        logger.info(
            ' - 🔀 Replacing version $oldVersion with $version in pubspec');
        element = 'version: $version';
      }
      return element;
    });

    return true;
  }

  Future<bool> _updateVersionDartFile(
      String packageRoot, String version, Logger logger, bool dryRun) async {
    final versionFile = File(path.join(packageRoot, 'lib/src/version.dart'));
    if (!versionFile.existsSync()) {
      logger.shout('⁉️ Could not find version.dart at ${versionFile.path}');
      return false;
    }

    await _transformFile(versionFile, logger, dryRun, (element) {
      if (element.startsWith('const ddPackageVersion')) {
        element = "const ddPackageVersion = '$version';";
      }
      return element;
    });

    return true;
  }

  Future<bool> _updateChangelog(
      String packageRoot, String version, Logger logger, bool dryRun) async {
    final changelogFile = File(path.join(packageRoot, 'CHANGELOG.md'));
    if (!changelogFile.existsSync()) {
      logger.shout('⁉️ Could not find CHANGELOG.md at ${changelogFile.path}');
      return false;
    }

    await _transformFile(changelogFile, logger, dryRun, (element) {
      if (element.startsWith('## Unreleased')) {
        element = '## Unreleased\n\n## $version';
      }
      return element;
    });

    return true;
  }
}
