import 'dart:io';

import 'package:logging/logging.dart';

import 'helpers.dart';

/// Matches a `build.gradle`'s `ext.datadog_version = "..."` assignment --
/// mirrors `native_sdk.dart`'s private matcher of the same shape, kept
/// separate deliberately (see `cocoapod_util.dart`'s equivalent note).
final _androidGradleVersionRewritePattern = RegExp(
  r'(?<prefix>ext\.datadog_version\s*=\s*")(?<version>[^"]+)(?<suffix>".*)',
);

/// Rewrites [gradleFile]'s `ext.datadog_version` assignment to pin at
/// [targetVersion] -- usable directly against any package's
/// `build.gradle` rather than only a hardcoded list.
Future<void> pinAndroidGradleVersion(
  File gradleFile,
  String targetVersion,
  Logger logger,
  bool dryRun,
) async {
  logger.info(
    'ℹ️ Pinning dd-sdk-android to $targetVersion in ${gradleFile.path}',
  );

  await transformFile(gradleFile, logger, dryRun, (line) {
    final match = _androidGradleVersionRewritePattern.firstMatch(line);
    if (match == null) return line;
    return '${match.namedGroup('prefix')}$targetVersion'
        '${match.namedGroup('suffix')}';
  });
}
