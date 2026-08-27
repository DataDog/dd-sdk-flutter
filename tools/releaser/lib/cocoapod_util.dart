import 'dart:io';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'command.dart';
import 'helpers.dart';
import 'native_sdk.dart';
import 'package_list.dart';

final overridesStartPattern = RegExp(r'\s+# Datadog Pod Overrides');
final overridesEndPattern = RegExp(r'\s+# End Datadog Pod Overrides');

/// Rewrites a podspec's `s.dependency 'Datadog...'` constraint to [version],
/// or returns [line] unchanged if it isn't one.
///
/// Replaces only the matched range rather than reconstructing the line.
/// [iosPodspecDependencyPattern] tolerates any spacing around the comma, so
/// rebuilding a canonical `  s.dependency 'X', 'Y'` reformats whatever
/// spacing and indentation the podspec actually used and drops anything
/// trailing the constraint.
String pinIosPodspecDependencyLine(String line, String version) {
  final match = iosPodspecDependencyPattern.firstMatch(line);
  if (match == null) return line;

  return line.replaceRange(
    match.start,
    match.end,
    "${match.namedGroup('prefix')}$version'",
  );
}

class PinCocoapodsVersionCommand extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    if (!await _removePodfileOverrides(args, logger)) {
      return false;
    }

    // Other packages can keep looser version constraints
    final pinedPackage = args.packages.firstWhereOrNull(
      (e) => e.name == 'datadog_flutter_plugin',
    );
    if (pinedPackage != null) {
      if (!await _pinPodspecVersion(args, pinedPackage, logger)) {
        return false;
      }
    }

    return true;
  }

  Future<bool> _removePodfileOverrides(
    CommandArguments args,
    Logger logger,
  ) async {
    logger.info('ℹ️ Removing overrides from Podfiles.');
    for (var filePath in podfileList) {
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

  Future<bool> _pinPodspecVersion(
    CommandArguments args,
    PackageRelease package,
    Logger logger,
  ) async {
    final podspecLocation = 'ios/${package.name}.podspec';

    final file = File(
      path.join(getPackageRoot(args, package), podspecLocation),
    );

    if (!file.existsSync()) {
      logger.warning(
        '⚠️ Could not find file $file. This is expected for non-core packages',
      );
      return true;
    }

    logger.info('ℹ️ Setting the iOS Pod Dependency to ${args.iOSRelease}');
    await transformFile(
      file,
      logger,
      args.dryRun,
      (element) => pinIosPodspecDependencyLine(element, args.iOSRelease!),
    );

    return true;
  }
}
