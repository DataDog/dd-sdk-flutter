// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:version/version.dart';

import 'command.dart';
import 'helpers.dart';

enum VersionBumpType { major, minor, rev, prerelease }

class UpdateVersionsCommand extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    if (!await updateVersions(
        args.packageRoot, args.version, logger, args.dryRun)) {
      return false;
    }

    return _updateChangelog(
        args.packageRoot, args.version, logger, args.dryRun);
  }
}

class BumpVersionCommand extends Command {
  final VersionBumpType bumpType;

  BumpVersionCommand(this.bumpType);

  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    final version = Version.parse(args.version);
    Version newVersion;
    switch (bumpType) {
      case VersionBumpType.major:
        newVersion = version.incrementMajor();
        break;
      case VersionBumpType.minor:
        newVersion = version.incrementMinor();
        break;
      case VersionBumpType.rev:
        newVersion = version.incrementPatch();
        break;
      case VersionBumpType.prerelease:
        try {
          newVersion = version.incrementPreRelease();
        } catch (e) {
          logger.shout(
              '❌ Failed to increment the pre-release version of $version. Is it not a pre-release?');
          return false;
        }
        break;
    }
    logger.info('🔀 Bumping version to $newVersion');
    return updateVersions(
        args.packageRoot, newVersion.toString(), logger, args.dryRun);
  }
}

final _versionCapture = RegExp(r'^version\: (?<version>.*)');

Future<bool> updateVersions(
    String packageRoot, String version, Logger logger, bool dryRun) async {
  if (!await _updatePackagePubspec(packageRoot, version, logger, dryRun)) {
    return false;
  }

  await _updateVersionDartFile(packageRoot, version, logger, dryRun);

  return true;
}

Future<bool> _updatePackagePubspec(
    String packageRoot, String version, Logger logger, bool dryRun) async {
  final pubspecFile = File(path.join(packageRoot, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    logger.shout('⁉️ Could not find pubspec.yaml at ${pubspecFile.path}');
    return false;
  }

  await transformFile(pubspecFile, logger, dryRun, (element) {
    final match = _versionCapture.firstMatch(element);
    if (match != null) {
      final oldVersion = match.namedGroup('version');
      logger
          .info(' - 🔀 Replacing version $oldVersion with $version in pubspec');
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
    logger.shout('This is ignored as it is expected for non-core packages.');
    return false;
  }

  await transformFile(versionFile, logger, dryRun, (element) {
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

  await transformFile(changelogFile, logger, dryRun, (element) {
    if (element.startsWith('## Unreleased')) {
      element = '## Unreleased\n\n## $version';
    }
    return element;
  });

  return true;
}
