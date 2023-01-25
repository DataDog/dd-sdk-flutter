import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'command.dart';
import 'helpers.dart';
import 'package_list.dart';

final overridesStartPattern = RegExp(r'\s+# Datadog Pod Overrides');
final overridesEndPattern = RegExp(r'\s+# End Datadog Pod Overrides');
final specDependencyPattern =
    RegExp(r"\s+s\.dependency\s+'(?<dependency>Datadog.+)', '.+");

class RemovePodOverridesCommand extends Command {
  final podspecLocation = 'ios/datadog_flutter_plugin.podspec';

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
    // Only modify files in the package we're shipping
    for (var filePath
        in podfileList.where((e) => e.contains(args.packageName))) {
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
    final file = File(path.join(
        args.gitDir.path, 'packages/${args.packageName}', podspecLocation));

    if (!file.existsSync()) {
      logger.warning(
          '⚠️ Could not find file $file. This is expected for non-core packages');
      return true;
    }

    logger.info('ℹ️ Setting the iOS Pod Dependency to ${args.iOSRelease}');
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
