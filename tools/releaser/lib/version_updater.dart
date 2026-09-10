// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'helpers.dart';

/// Adds (or, if already present, leaves alone) a row to [nativeSdkVersionsFile]
/// recording [packageVersion] against the native SDK versions it was built
/// against -- the discovery-driven equivalent of `_updateNativeSDKVersions`,
/// usable directly against a [File] without the legacy
/// `CommandArguments`/`PackageRelease` coupling. Any of [iosVersion]/
/// [androidVersion]/[cppVersion] may be null when this package doesn't
/// wrap that SDK.
Future<void> updateNativeSdkVersionsMd(
  File nativeSdkVersionsFile,
  String packageVersion,
  Logger logger,
  bool dryRun, {
  String? iosVersion,
  String? androidVersion,
  String? cppVersion,
}) async {
  final newVersionEntry =
      '| $packageVersion | ${iosVersion ?? '-'} | ${androidVersion ?? '-'} '
      '| ${cppVersion ?? '-'} |';
  const header = '| Flutter | iOS SDK | Android SDK | C++ SDK |';
  const separator = '|---------|---------|-------------|---------|';

  if (!nativeSdkVersionsFile.existsSync()) {
    logger.warning(
      '⚠️ ${nativeSdkVersionsFile.path} does not exist, creating it now.',
    );
    if (!dryRun) {
      await nativeSdkVersionsFile.writeAsString(
        '$header\n$separator\n$newVersionEntry\n',
      );
    }
    return;
  }

  final lines = await nativeSdkVersionsFile.readAsLines();
  for (final line in lines) {
    if (!line.startsWith('|')) continue;
    final parts = line.split('|').map((s) => s.trim()).toList();
    if (parts.length > 1 && parts[1] == packageVersion) {
      logger.info(
        '✅ Version $packageVersion already exists in '
        '${nativeSdkVersionsFile.path}, skipping.',
      );
      return;
    }
  }

  await transformFile(nativeSdkVersionsFile, logger, dryRun, (line) {
    if (line.startsWith('|-')) {
      return '$separator\n$newVersionEntry';
    }
    return line;
  });
}

const _sdkTableStartMarker = '[//]: # (SDK Table)';
const _sdkTableEndMarker = '[//]: # (End SDK Table)';

/// Rewrites the `[//]: # (SDK Table)` ... `[//]: # (End SDK Table)` block
/// in [readmeFile] to the current SDK versions -- only the app-facing
/// package of a federated group carries this table, so this is a no-op
/// (not an error) if the markers aren't found. Browser SDK isn't tracked
/// by this tool, so it's carried over as a fixed "7.x.x", matching prior
/// behavior. Any of [iosVersion]/[androidVersion]/[cppVersion] may be
/// null when this package doesn't wrap that SDK.
Future<void> updateReadmeSdkTable(
  File readmeFile,
  Logger logger,
  bool dryRun, {
  String? iosVersion,
  String? androidVersion,
  String? cppVersion,
}) async {
  if (!readmeFile.existsSync()) return;

  final newTable =
      '$_sdkTableStartMarker\n\n'
      '| iOS SDK | Android SDK | C++ SDK | Browser SDK |\n'
      '| :-----: | :---------: | :-----: | :---------: |\n'
      '| ${iosVersion ?? '-'} | ${androidVersion ?? '-'} '
      '| ${cppVersion ?? '-'} | 7.x.x |\n\n'
      '$_sdkTableEndMarker';

  var inTable = false;
  var foundTable = false;
  await transformFile(readmeFile, logger, dryRun, (line) {
    if (inTable) {
      if (line.trim() == _sdkTableEndMarker) {
        inTable = false;
        return newTable;
      }
      return null;
    } else if (line.trim() == _sdkTableStartMarker) {
      inTable = true;
      foundTable = true;
      return null;
    }
    return line;
  });

  if (!foundTable) {
    logger.fine('No SDK table markers in ${readmeFile.path}, skipping.');
  }
}

final _versionCapture = RegExp(r'^version\: (?<version>.*)');

Future<bool> updateVersions(
  String packageRoot,
  String version,
  Logger logger,
  bool dryRun,
) async {
  if (!await _updatePackagePubspec(packageRoot, version, logger, dryRun)) {
    return false;
  }

  await _updateVersionDartFile(packageRoot, version, logger, dryRun);

  return true;
}

Future<bool> _updatePackagePubspec(
  String packageRoot,
  String version,
  Logger logger,
  bool dryRun,
) async {
  final pubspecFile = File(path.join(packageRoot, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    logger.shout('⁉️ Could not find pubspec.yaml at ${pubspecFile.path}');
    return false;
  }

  await transformFile(pubspecFile, logger, dryRun, (element) {
    final match = _versionCapture.firstMatch(element);
    if (match != null) {
      final oldVersion = match.namedGroup('version');
      logger.info(
        ' - 🔀 Replacing version $oldVersion with $version in pubspec',
      );
      element = 'version: $version';
    }
    return element;
  });

  return true;
}

Future<bool> _updateVersionDartFile(
  String packageRoot,
  String version,
  Logger logger,
  bool dryRun,
) async {
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
