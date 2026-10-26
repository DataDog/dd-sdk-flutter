import 'dart:io';

import 'package:logging/logging.dart';

import 'helpers.dart';

/// Matches a podspec's `s.dependency 'Datadog...', '<constraint>'` line --
/// mirrors `native_sdk.dart`'s private matcher of the same shape, kept
/// separate deliberately: a matcher wants to be permissive, a rewriter has
/// to reproduce exactly what it matched.
final _iosPodspecDependencyRewritePattern = RegExp(
  r"(?<prefix>\s+s\.dependency\s+'Datadog\w*'\s*,\s*')(?<constraint>[^']+)(?<suffix>'.*)",
);

/// Also used by `bin/pinner.dart` to strip its own Podfile overrides block.
final overridesStartPattern = RegExp(r'\s+# Datadog Pod Overrides');
final overridesEndPattern = RegExp(r'\s+# End Datadog Pod Overrides');

/// Rewrites [podspecFile]'s `s.dependency 'Datadog...', '<constraint>'`
/// line to pin at [targetVersion] -- usable directly against any package's
/// podspec rather than only `datadog_flutter_plugin`'s.
Future<void> pinIosPodspecVersion(
  File podspecFile,
  String targetVersion,
  Logger logger,
  bool dryRun,
) async {
  logger.info('ℹ️ Pinning dd-sdk-ios to $targetVersion in ${podspecFile.path}');

  await transformFile(podspecFile, logger, dryRun, (line) {
    final match = _iosPodspecDependencyRewritePattern.firstMatch(line);
    if (match == null) return line;
    return '${match.namedGroup('prefix')}$targetVersion'
        '${match.namedGroup('suffix')}';
  });
}

/// Strips the `# Datadog Pod Overrides` ... `# End Datadog Pod Overrides`
/// block from [podfileFile] in place, if present -- unlike the Dart-side
/// `dependency_overrides`, these `:git => ..., :branch => 'develop'` pod
/// entries are still a real, committed thing example apps use to float on
/// dd-sdk-ios's `develop` branch, so they do need removing before a
/// release-prep build is expected to resolve to a pinned, released
/// version. No-op if the file has no such block.
Future<void> removePodfileOverrides(
  File podfileFile,
  Logger logger,
  bool dryRun,
) async {
  logger.info('🔀 Removing Datadog Pod Overrides from ${podfileFile.path}');

  var removingLines = false;
  await transformFile(podfileFile, logger, dryRun, (line) {
    if (removingLines) {
      if (line.startsWith(overridesEndPattern)) {
        removingLines = false;
      }
      return null;
    } else if (line.startsWith(overridesStartPattern)) {
      removingLines = true;
      return null;
    }
    return line;
  });
}
