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
const _nativeSdkColumns = ['Flutter', 'iOS SDK', 'Android SDK', 'C++ SDK'];

String _renderMdTableRow(List<String> values) => '| ${values.join(' | ')} |';

String _renderMdSeparatorRow(List<String> columns) =>
    '|${columns.map((c) => '-' * (c.length + 2)).join('|')}|';

Future<void> updateNativeSdkVersionsMd(
  File nativeSdkVersionsFile,
  String packageVersion,
  Logger logger,
  bool dryRun, {
  String? iosVersion,
  String? androidVersion,
  String? cppVersion,
}) async {
  final newValues = {
    'Flutter': packageVersion,
    'iOS SDK': iosVersion,
    'Android SDK': androidVersion,
    'C++ SDK': cppVersion,
  };

  if (!nativeSdkVersionsFile.existsSync()) {
    // Only the platform(s) this package actually ships -- a brand-new file
    // is always a single-platform package's own (post-4.0, per-platform)
    // NATIVE_SDK_VERSIONS.md, never the app-facing package's aggregate
    // table, so there's no reason for it to carry other platforms' columns
    // filled with '-'.
    final columns = [
      for (final c in _nativeSdkColumns)
        if (c == 'Flutter' || newValues[c] != null) c,
    ];
    if (columns.length == 1) {
      // Nothing but 'Flutter' -- this package ships no native SDK at all,
      // so it shouldn't have a NATIVE_SDK_VERSIONS.md in the first place.
      return;
    }
    logger.warning(
      '⚠️ ${nativeSdkVersionsFile.path} does not exist, creating it now.',
    );
    if (!dryRun) {
      final header = _renderMdTableRow(columns);
      final separator = _renderMdSeparatorRow(columns);
      final row = _renderMdTableRow(
        columns.map((c) => newValues[c] ?? '-').toList(),
      );
      await nativeSdkVersionsFile.writeAsString(
        '$header\n$separator\n$row\n',
      );
    }
    return;
  }

  final lines = await nativeSdkVersionsFile.readAsLines();
  final headerIndex = lines.indexWhere((l) => l.trimLeft().startsWith('|'));
  if (headerIndex == -1 || headerIndex + 1 >= lines.length) {
    logger.warning(
      '⚠️ Could not find a markdown table header in '
      '${nativeSdkVersionsFile.path}, skipping.',
    );
    return;
  }
  final separatorIndex = headerIndex + 1;
  final bodyStartIndex = separatorIndex + 1;

  final existingColumns = lines[headerIndex]
      .split('|')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  for (final line in lines.skip(bodyStartIndex)) {
    if (!line.trimLeft().startsWith('|')) continue;
    final parts = line.split('|').map((s) => s.trim()).toList();
    if (parts.length > 1 && parts[1] == packageVersion) {
      logger.info(
        '✅ Version $packageVersion already exists in '
        '${nativeSdkVersionsFile.path}, skipping.',
      );
      return;
    }
  }

  // The column set only ever grows -- e.g. a package's first release that
  // wraps a C++ SDK -- so existing rows are backfilled with '-' for any
  // newly-added column rather than left narrower than the new header.
  final columns = [
    for (final c in _nativeSdkColumns)
      if (existingColumns.contains(c) ||
          (c != 'Flutter' && newValues[c] != null))
        c,
  ];
  final columnGrew = columns.length != existingColumns.length;

  if (!dryRun) {
    final newLines = <String>[
      ...lines.take(headerIndex),
      _renderMdTableRow(columns),
      _renderMdSeparatorRow(columns),
      // New entries go at the top of the body, newest-first, matching the
      // existing convention.
      _renderMdTableRow(columns.map((c) => newValues[c] ?? '-').toList()),
    ];

    for (final line in lines.skip(bodyStartIndex)) {
      if (!line.trimLeft().startsWith('|') || !columnGrew) {
        newLines.add(line);
        continue;
      }
      final parts = line
          .split('|')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final byColumn = {
        for (var i = 0; i < existingColumns.length && i < parts.length; i++)
          existingColumns[i]: parts[i],
      };
      newLines.add(
        _renderMdTableRow(columns.map((c) => byColumn[c] ?? '-').toList()),
      );
    }

    await nativeSdkVersionsFile.writeAsString('${newLines.join('\n')}\n');
    logger.info(' ✏️ Wrote ${nativeSdkVersionsFile.path}');
  }
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

final _versionCapture = RegExp(r'^version:\s*(?<version>.*)');

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

  var foundVersionLine = false;
  await transformFile(pubspecFile, logger, dryRun, (element) {
    final match = _versionCapture.firstMatch(element);
    if (match != null) {
      foundVersionLine = true;
      final oldVersion = match.namedGroup('version');
      logger.info(
        ' - 🔀 Replacing version $oldVersion with $version in pubspec',
      );
      element = 'version: $version';
    }
    return element;
  });

  if (!foundVersionLine) {
    logger.shout(
      '⁉️ Could not find a "version:" line in ${pubspecFile.path}',
    );
    return false;
  }

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
