import 'dart:io';

import 'package:logging/logging.dart';

import 'helpers.dart';

/// Matches a `build.gradle`'s `ext.datadog_version = "..."` assignment --
/// mirrors `native_sdk.dart`'s private matcher of the same shape, kept
/// separate deliberately (see `cocoapod_util.dart`'s equivalent note).
final _androidGradleVersionRewritePattern = RegExp(
  r'^(?<indent>\s*)(?<prefix>ext\.datadog_version\s*=\s*")(?<version>[^"]+)(?<suffix>".*)',
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
    return '${match.namedGroup('indent')}${match.namedGroup('prefix')}'
        '$targetVersion${match.namedGroup('suffix')}';
  });
}

/// Matches the opening line of a `maven { ... }` repository block --
/// whether or not it closes on the same line.
final _mavenBlockStartPattern = RegExp(r'\bmaven\s*\{');

/// Matches a `url` pointing at Sonatype's central snapshots repo, inside a
/// `maven { ... }` block.
final _snapshotsUrlPattern = RegExp(r'\burl\b.*maven-snapshots');

int _braceBalance(String line) =>
    '{'.allMatches(line).length - '}'.allMatches(line).length;

/// Strips any `maven { ... }` block whose `url` points at Sonatype's
/// snapshots repo from [gradleFile] -- present in example apps for
/// day-to-day development against an unreleased dd-sdk-android build, but
/// must never survive onto a release branch. A package's own `build.gradle`
/// can declare this via `rootProject.allprojects { repositories { ... } }`
/// to inject it into every consuming app's build, not just its own -- that
/// gets stripped the same way, wherever the maven block itself appears.
///
/// Tracks brace depth rather than closing on a block's first `}`, since a
/// maven block can nest another block of its own before it closes (e.g. a
/// JitPack entry's `content { includeGroup ... }`) -- mirrors
/// `cmake_util.dart`'s paren-depth block scanner for the same reason.
Future<void> removeSnapshotsMavenRepository(
  File gradleFile,
  Logger logger,
  bool dryRun,
) async {
  logger.info('🔀 Removing snapshots maven repository from ${gradleFile.path}');

  final block = <String>[];
  var inBlock = false;
  var depth = 0;
  var isSnapshotsBlock = false;

  String? closeBlock() {
    inBlock = false;
    final result = isSnapshotsBlock ? null : block.join('\n');
    block.clear();
    isSnapshotsBlock = false;
    depth = 0;
    return result;
  }

  await transformFile(gradleFile, logger, dryRun, (line) {
    if (inBlock) {
      block.add(line);
      if (_snapshotsUrlPattern.hasMatch(line)) isSnapshotsBlock = true;
      depth += _braceBalance(line);
      return depth <= 0 ? closeBlock() : null;
    }

    if (_mavenBlockStartPattern.hasMatch(line)) {
      inBlock = true;
      block.add(line);
      if (_snapshotsUrlPattern.hasMatch(line)) isSnapshotsBlock = true;
      depth = _braceBalance(line);
      // A single-line `maven { url "..." }` block closes immediately.
      return depth <= 0 ? closeBlock() : null;
    }

    return line;
  });
}
