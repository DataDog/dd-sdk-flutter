// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:version/version.dart';

import 'command.dart';
import 'helpers.dart';

enum VersionBumpType { major, minor, rev, prerelease }

class UpdateVersionsCommand extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    for (final package in args.packages) {
      final packageRoot = getPackageRoot(args, package);
      if (!await updateVersions(
          packageRoot, package.version, logger, args.dryRun)) {
        return false;
      }
    }

    final corePackage = args.packages
        .firstWhereOrNull((e) => e.name == 'datadog_flutter_plugin');

    if (corePackage != null) {
      if (!await _updateReadmeVersions(args, corePackage, logger)) {
        return false;
      }

      if (!await _updateNativeSDKVersions(args, corePackage, logger)) {
        return false;
      }
    }

    return true;
  }
}

class BumpVersionCommand extends Command {
  final VersionBumpType bumpType;

  BumpVersionCommand(this.bumpType);

  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    bool success = true;
    for (final package in args.packages) {
      final version = Version.parse(package.version);
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
      success &= await updateVersions(getPackageRoot(args, package),
          newVersion.toString(), logger, args.dryRun);
    }
    return success;
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

Future<bool> _updateReadmeVersions(
    CommandArguments args, PackageRelease package, Logger logger) async {
  final packageRoot = getPackageRoot(args, package);
  final changelogFile = File(path.join(packageRoot, 'README.md'));
  if (!changelogFile.existsSync()) {
    logger.shout('⁉️ Could not find README.md at ${changelogFile.path}');
    return false;
  }

  var inVersionTable = false;
  await transformFile(changelogFile, logger, args.dryRun, (line) {
    if (inVersionTable) {
      if (line.startsWith('[//]: #')) {
        inVersionTable = false;

        // Write the new version table:
        line = '''[//]: # (SDK Table)

| iOS SDK | Android SDK | Browser SDK |
| :-----: | :---------: | :---------: |
| ${args.iOSRelease} | ${args.androidRelease} | 5.x.x |

[//]: # (End SDK Table)''';
        return line;
      }

      // Return no lines for the entire version table.
      return null;
    } else if (line == '[//]: # (SDK Table)') {
      inVersionTable = true;
      return null;
    }

    return line;
  });

  return true;
}

Future<bool> _updateNativeSDKVersions(
    CommandArguments args, PackageRelease package, Logger logger) async {
  final packageRoot = getPackageRoot(args, package);
  final nativeSDKVersionsFile =
      File(path.join(packageRoot, 'NATIVE_SDK_VERSIONS.md'));
  final newVersionEntry =
      '| ${package.version} | ${args.iOSRelease} | ${args.androidRelease} |';
  final header = '| Flutter | iOS SDK | Android SDK |';
  final separator = '|---------|---------|-------------|';

  if (!nativeSDKVersionsFile.existsSync()) {
    logger
        .warning('⚠️ NATIVE_SDK_VERSIONS.md does not exist, creating it now.');
    await nativeSDKVersionsFile
        .writeAsString('$header\n$separator\n$newVersionEntry');
    return true;
  }

  final lines = await nativeSDKVersionsFile.readAsLines();
  for (final line in lines) {
    if (!line.startsWith('|')) continue;

    final parts = line.split('|').map((s) => s.trim()).toList();
    if (parts.length > 1 && parts[1] == package.version) {
      logger.info(
          '✅ Version ${package.version} already exists in NATIVE_SDK_VERSIONS.md, skipping.');
      return true;
    }
  }

  await transformFile(nativeSDKVersionsFile, logger, args.dryRun, (line) {
    if (line.startsWith('|-')) {
      return '$separator\n$newVersionEntry';
    }

    return line;
  });

  return true;
}
