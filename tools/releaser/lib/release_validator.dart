// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'command.dart';
import 'github_cmd_wrapper.dart';
import 'helpers.dart';
import 'process_helper.dart';

final versionHeadingRegEx = RegExp(r'\s*#');
final changeItemRegEx = RegExp(r'\s*\*');

class ValidateReleaseCommand extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    final gitRoot = args.gitDir.path;
    logger.finest(' -- Monorepo root is $gitRoot');

    if (!args.dryRun && !args.skipGitChecks) {
      if (!await _validateBranchState(args.gitDir, logger)) {
        return false;
      }
    }

    // From here on out, we can validate multiple rules before returning.
    bool isValid = true;
    for (final release in args.packages) {
      final packagePath = path.join(gitRoot, 'packages', release.name);
      logger.finest(' -- Checking valid native releases for ${release.name}');
      if (hasNativeDependency(release.name)) {
        if (!await _validateiOSRelease(packagePath, args, logger)) {
          isValid = false;
        }
        if (!await _validateAndroidRelease(packagePath, args, logger)) {
          isValid = false;
        }
      }
    }

    return isValid;
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
          '❌ We really should only release from `develop` or another `release` branch.');
      return false;
    }

    return true;
  }

  Future<bool> _validateiOSRelease(
      String packagePath, CommandArguments args, Logger logger) async {
    args.iOSRelease = await _validateReleaseVersion(
        args, 'DataDog/dd-sdk-ios', 'iOS', args.iOSRelease, logger);
    return args.iOSRelease != null;
  }

  Future<bool> _validateAndroidRelease(
      String packagePath, CommandArguments args, Logger logger) async {
    args.androidRelease = await _validateReleaseVersion(
        args, 'DataDog/dd-sdk-android', 'Android', args.androidRelease, logger);

    return args.androidRelease != null;
  }

  Future<String?> _validateReleaseVersion(
    CommandArguments args,
    String repoName,
    String platform,
    String? release,
    Logger logger,
  ) async {
    // If we didn't specify a version get the current latest release from github.
    // If we did specify a release, check that it actually exists.
    final gh = GithubCommandWrapper(args.gitDir.path);
    if (release == null) {
      logger.fine('🌎 Fetching latest $platform release from github... ');
      final latestRelease = await gh.getLatestRelease(logger, repoName);
      logger.fine('ℹ️ Latest $platform release is ${latestRelease.name}');
      release = latestRelease.tagName;
    } else {
      final ghRelease = await gh.getReleaseByTagName(logger, repoName, release);
      if (ghRelease == null) {
        logger.shout(
            '❌ Could not find target $platform release $release. Please check the tag name');
        return null;
      }
    }

    logger.info('ℹ️ Releasing with $platform version $release.');

    return release;
  }
}

class ValidatePublishDryRun extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    var finalResult = true;
    for (final package in args.packages) {
      final packageRoot = getPackageRoot(args, package);
      logger.info('ℹ️ Running `flutter pub publish --dry-run` in $packageRoot');
      final exitCode = await runProcess(
        'flutter',
        ['pub', 'publish', '--dry-run'],
        workingDirectory: packageRoot,
        stdout: (line) => logger.fine(line),
        stderr: (line) => logger.shout(line),
      );
      if (exitCode != 0) {
        logger.info('❌ Publish exited with code $exitCode.');
        logger.info('Fix the above errors and try again.');
        return finalResult = false;
      } else {
        logger.info('✅ Publish dry-run went fine.');
      }
    }

    return finalResult;
  }
}
