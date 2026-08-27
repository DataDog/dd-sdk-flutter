import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'command.dart';
import 'helpers.dart';
import 'native_sdk.dart';
import 'package_list.dart';

/// Rewrites a `build.gradle`'s `ext.datadog_version` assignment to [version],
/// or returns [line] unchanged if it isn't that assignment.
///
/// Rebuilt from the match rather than from a literal `ext.datadog_version =
/// "..."`: [androidGradleVersionPattern] tolerates any spacing around the `=`,
/// so a literal would match a line and then silently replace nothing in it,
/// leaving the constraint unpinned with no error. Replacing the matched range
/// also keeps the line's own spacing and indentation.
String pinAndroidGradleVersionLine(String line, String version) {
  final match = androidGradleVersionPattern.firstMatch(line);
  if (match == null) return line;

  return line.replaceRange(
    match.start,
    match.end,
    '${match.namedGroup('prefix')}$version"',
  );
}

class UpdateGradleFilesCommand extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    if (!await _updateGradleFiles(args, logger)) {
      return false;
    }

    return true;
  }

  Future<bool> _updateGradleFiles(CommandArguments args, Logger logger) async {
    // Resolved by ValidateReleaseCommand -- but only for packages that pass
    // hasNativeDependency(), which is a stale two-name list. Releasing
    // anything else skips that validation entirely and leaves this null while
    // still returning success, so it has to be guarded here rather than
    // interpolated: this loop walks a hardcoded gradleList and rewrites any
    // datadog_flutter_plugin path regardless of what's actually being
    // released, so an unguarded null wrote a literal
    // `ext.datadog_version = "null"` into a package that need not even be part
    // of the release -- and the next CommitChangesCommand shipped it.
    //
    // Leaving the pin floating is the safe failure: it's what develop already
    // carries, and it shows up in the release diff as "nothing changed"
    // instead of as a corrupted constraint.
    final androidRelease = args.androidRelease;
    if (androidRelease == null) {
      logger.warning(
        '⚠️ No Android SDK version was resolved for this release -- leaving '
        'ext.datadog_version alone. Pass --android-version if this release is '
        'meant to move the Android SDK pin.',
      );
    }

    for (var filePath in gradleList) {
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
        // For the datadog_flutter_plugin, use a tighter constraint
        if (androidRelease != null &&
            file.path.contains('datadog_flutter_plugin')) {
          line = pinAndroidGradleVersionLine(line, androidRelease);
        }

        // Remove requests for external gradle files
        if (line.contains("apply from: '../")) return null;

        if (line.contains('maven ')) {
          inMavenBlock = true;
        }

        if (inMavenBlock) {
          mavenBlock.writeln(line);
          if (line.contains('url') && line.contains('/maven-snapshots/')) {
            // this is a request for a snapshots maven repo. Don't write it to the final file
            writeMavenBlock = false;
          }
          if (line.contains('}')) {
            String? returnLine;
            inMavenBlock = false;
            if (writeMavenBlock) {
              returnLine = mavenBlock.toString();
            }

            // Reset to default values
            mavenBlock.clear();
            writeMavenBlock = true;

            return returnLine;
          }
          return null;
        }

        return line;
      });
    }

    return true;
  }
}
