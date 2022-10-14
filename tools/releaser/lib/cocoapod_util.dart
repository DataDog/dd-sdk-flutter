import 'dart:io';

import 'package:logging/src/logger.dart';
import 'package:path/path.dart' as path;

import 'command.dart';
import 'helpers.dart';

final overridesStartPattern = RegExp(r'\s+# Datadog Pod Overrides');
final overridesEndPattern = RegExp(r'\s+# End Datadog Pod Overrides');
final specDependencyPattern =
    RegExp(r"\s+s\.dependency\s+'(?<dependency>Datadog.+)', '.+");

class RemovePodOverridesCommand extends Command {
  final podfileLocations = [
    'packages/datadog_flutter_plugin/e2e_test_app/ios/Podfile',
    'packages/datadog_flutter_plugin/example/ios/Podfile',
    'packages/datadog_flutter_plugin/integration_test_app/ios/Podfile',
    'packages/datadog_tracking_http_client/example/ios/Podfile',
  ];

  final podspecLocation =
      'packages/datadog_flutter_plugin/ios/datadog_flutter_plugin.podspec';

  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    if (!await _removePodfileOverrides(args, logger)) {
      return false;
    }

    if (!await _pinPodspecVersion(args, logger)) {
      return false;
    }

    return true;
  }

  Future<bool> _removePodfileOverrides(
      CommandArguments args, Logger logger) async {
    logger.info('ℹ️ Removing overrides from Podfiles.');
    for (var filePath in podfileLocations) {
      final file = File(path.join(args.gitDir.path, filePath));
      if (!file.existsSync()) {
        logger.shout('❌ Could not find file $filePath');
        return false;
      }

      bool removingLines = false;
      logger.fine('-- ℹ️ Removing overrides from $filePath');
      await transformFile(file, logger, args.dryRun, (element) {
        if (removingLines && element.startsWith(overridesEndPattern)) {
          removingLines = false;
          // Remove the end pattern line
          return null;
        } else if (element.startsWith(overridesStartPattern)) {
          removingLines = true;
        }

        return removingLines ? null : element;
      });
    }

    return true;
  }

  Future<bool> _pinPodspecVersion(CommandArguments args, Logger logger) async {
    logger.info('ℹ️ Setting the iOS Pod Dependency to ${args.iOSRelease}');

    final file = File(path.join(args.gitDir.path, podspecLocation));
    if (!file.existsSync()) {
      logger.shout('❌ Could not find file $podspecLocation');
      return false;
    }

    await transformFile(file, logger, args.dryRun, (element) {
      final match = specDependencyPattern.firstMatch(element);
      if (match != null) {
        element =
            "  s.dependency '${match.namedGroup('dependency')}', '${args.iOSRelease}'";
      }
      return element;
    });

    return true;
  }
}
