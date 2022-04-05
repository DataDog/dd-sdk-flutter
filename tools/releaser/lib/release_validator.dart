// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:version/version.dart';

import 'command.dart';

final versionHeadingRegEx = RegExp(r'\s*#');
final changeItemRegEx = RegExp(r'\s*\*');

class ValidateReleaseCommand extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    final gitRoot = args.gitDir.path;
    logger.finest(' -- Monorepo root is $gitRoot');
    final packagePath = path.join(gitRoot, 'packages', args.packageName);
    logger.finest(' -- Package root is $packagePath');

    if (!args.dryRun && !args.skipGitChecks) {
      if (!await _validateBranchState(args.gitDir, logger)) {
        return false;
      }
    }

    // From here on out, we can validate multiple rules before returning.
    bool isValid = true;

    isValid &= _validateVersionNumber(args.version, logger);
    isValid &= await _validateChangeLog(packagePath, logger);

    return isValid;
  }

  bool _validateVersionNumber(String versionNumber, Logger logger) {
    try {
      final _ = Version.parse(versionNumber);
      return true;
    } on FormatException {
      logger.shout(
          '❌ Version $versionNumber does not parse properly as a semantic version');
    }
    return false;
  }

  Future<bool> _validateBranchState(GitDir gitDir, Logger logger) async {
    // Don't allow unstaged changes
    if (!await gitDir.isWorkingTreeClean()) {
      logger.shout(
          '❌ Working tree is not clean. Please stage or revert your changes before attempting to release.');
      return false;
    }

    // Only allow release from develop or a release/* branch
    final currentBranch = await gitDir.currentBranch();
    if (!(currentBranch.branchName == 'develop' ||
        currentBranch.branchName.startsWith('release'))) {
      logger.shout(
          '❌ We really should only prep releases from `develop` or another `release` branch.');
      return false;
    }

    return true;
  }

  Future<bool> _validateChangeLog(String packagePath, Logger logger) async {
    bool isValid = true;

    // Check the changelog for changes
    logger.fine('Checking CHANGELOG.md at $packagePath for changes...');
    final changeLogPath = path.join(packagePath, 'CHANGELOG.md');
    final changeLogFile = File(changeLogPath);
    if (!await changeLogFile.exists()) {
      logger.shout('Could not find a CHANGELOG.md at $changeLogPath');
      isValid = false;
    } else {
      var unreleasedLine = -1;
      var changes = 0;
      var lines = await changeLogFile.readAsLines();
      for (int i = 0; i < lines.length; ++i) {
        final line = lines[i];
        if (unreleasedLine < 0) {
          if (line.startsWith('## Unreleased')) {
            unreleasedLine = i;
          }
        } else if (unreleasedLine > 0) {
          // Assume the next heading is a released version
          if (line.startsWith(versionHeadingRegEx)) {
            break;
          } else if (line.startsWith(changeItemRegEx)) {
            changes++;
          }
        }
      }
      if (unreleasedLine < 0) {
        logger.shout('❌ No heading for an unreleased version found.');
        isValid = false;
      } else if (changes == 0) {
        logger.shout(
            '❌ No changes listed in the changelog for the unreleased version.');
        isValid = false;
      }
    }

    return isValid;
  }
}

class ValidatePublishDryRun extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    if (args.dryRun) {
      logger.info(
          '⚠️ Skipping `dart pub publish --dry-run` step due to --dry-run');
      return true;
    }

    logger.info('ℹ️ Running `dart pub publish --dry-run`');
    var process = await Process.start('dart', ['pub', 'publish', '--dry-run'],
        workingDirectory: args.packageRoot);
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((event) {
      logger.fine(event);
    });
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((event) {
      logger.shout(event);
    });

    var exitCode = await process.exitCode;
    if (exitCode != 0) {
      logger.info('❌ Publish exited with code $exitCode.');
      logger.info('Fix the above errors and try again.');
      return false;
    } else {
      logger.info('✅ Publish dry-run went fine.');
    }

    return true;
  }
}
