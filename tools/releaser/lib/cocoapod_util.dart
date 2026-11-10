import 'dart:io';

import 'package:logging/logging.dart';

import 'helpers.dart';
import 'native_sdk.dart';

/// Matches a podspec's `s.dependency 'Datadog...', '<constraint>'` line --
/// mirrors `native_sdk.dart`'s private matcher of the same shape, kept
/// separate deliberately: a matcher wants to be permissive, a rewriter has
/// to reproduce exactly what it matched.
final _iosPodspecDependencyRewritePattern = RegExp(
  r"(?<prefix>\s+s\.dependency\s+'(?<pod>Datadog\w*)'\s*,\s*')(?<constraint>[^']+)(?<suffix>'.*)",
);

typedef CocoaPodsVersionLookup =
    Future<bool> Function(String pod, String version);

/// Checks the public CocoaPods registry for a specific pod version.
Future<bool> cocoaPodVersionExists(
  String pod,
  String version, {
  HttpClient? client,
}) async {
  final http = client ?? HttpClient();
  try {
    final request = await http
        .getUrl(
          Uri.https('trunk.cocoapods.org', '/api/v1/pods/$pod/specs/$version'),
        )
        .timeout(const Duration(seconds: 30));
    final response = await request.close().timeout(const Duration(seconds: 30));
    await response.drain<void>().timeout(const Duration(seconds: 30));
    if (response.statusCode == HttpStatus.ok) return true;
    if (response.statusCode == HttpStatus.notFound) return false;
    throw StateError(
      'CocoaPods returned ${response.statusCode} for $pod $version. '
      'Release preparation requires a successful registry check.',
    );
  } finally {
    if (client == null) http.close(force: true);
  }
}

/// Validates every CocoaPods dependency that release preparation will pin.
Future<void> validateIosPodAvailability(
  Iterable<NativeSdkDelta> deltas, {
  CocoaPodsVersionLookup lookup = cocoaPodVersionExists,
}) async {
  final checked = <(String, String)>{};
  for (final delta in deltas) {
    final version = delta.targetVersion;
    if (delta.sdk != NativeSdk.ios || version == null) continue;
    for (final file in delta.files.where((f) => f.path.endsWith('.podspec'))) {
      final content = await file.readAsString();
      for (final match in _iosPodspecDependencyRewritePattern.allMatches(
        content,
      )) {
        final pod = match.namedGroup('pod')!;
        if (!checked.add((pod, version))) continue;
        if (!await lookup(pod, version)) {
          throw StateError(
            'CocoaPods does not contain $pod $version. Select a published '
            'version with --ios-sdk-version, or wait for native publication.',
          );
        }
      }
    }
  }
}

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
