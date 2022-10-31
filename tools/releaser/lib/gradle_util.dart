import 'dart:io';

import 'package:logging/src/logger.dart';
import 'package:path/path.dart' as path;

import 'command.dart';
import 'helpers.dart';

class UpdateGradleFilesCommand extends Command {
  final gradleFileLocations = [
    'packages/datadog_flutter_plugin/android/build.gradle',
    'packages/datadog_flutter_plugin/example/android/build.gradle',
  ];

  static const versionPrefix = 'datadog-android';
  final versionRegex = RegExp('$versionPrefix = "(.*)"');
  final versionCatalog =
      'packages/datadog_flutter_plugin/android/datadog_version.toml';

  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    if (!await _updateGradleFiles(args, logger)) {
      return false;
    }

    if (!await _updateVersionCatalog(args, logger)) {
      return false;
    }

    return true;
  }

  Future<bool> _updateGradleFiles(CommandArguments args, Logger logger) async {
    for (var filePath in gradleFileLocations) {
      final file = File(path.join(args.gitDir.path, filePath));
      if (!file.existsSync()) {
        logger.shout('❌ Could not find file $filePath');
        return false;
      }

      // IF we see a maven block, hold onto it until we know if it's
      // one we want to keep or remove
      final mavenBlock = StringBuffer();
      bool inMavenBlock = false;
      bool writeMavenBlock = true;
      await transformFile(file, logger, args.dryRun, (line) {
        if (line.contains('maven ')) {
          inMavenBlock = true;
        }

        if (inMavenBlock) {
          mavenBlock.writeln(line);
          if (line.contains('url') && line.contains('/snapshots/')) {
            // this is a request for a snapshots maven repo. Don't write it to the final file
            writeMavenBlock = false;
          }
          if (line.contains('}')) {
            inMavenBlock = false;
            if (writeMavenBlock) {
              line = mavenBlock.toString();
            } else {
              line = '';
            }

            // Reset to default values
            mavenBlock.clear();
            writeMavenBlock = true;

            return line;
          }
          return null;
        }

        return line;
      });
    }

    return true;
  }

  Future<bool> _updateVersionCatalog(
      CommandArguments args, Logger logger) async {
    final file = File(path.join(args.gitDir.path, versionCatalog));
    if (!file.existsSync()) {
      logger.shout('❌ Could not find file $versionCatalog');
      return false;
    }

    // IF we see a maven block, hold onto it until we know if it's
    // one we want to keep or remove
    final mavenBlock = StringBuffer();
    bool inMavenBlock = false;
    bool writeMavenBlock = true;
    await transformFile(file, logger, args.dryRun, (line) {
      final versionMatch = versionRegex.firstMatch(line);
      if (versionMatch != null) {
        final oldVersion = versionMatch.group(1);
        line = line.replaceFirst('$versionPrefix = "$oldVersion"',
            '$versionPrefix = "${args.androidRelease}"');
      }

      return line;
    });

    return true;
  }
}
