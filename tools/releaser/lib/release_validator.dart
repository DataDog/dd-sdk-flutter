// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:git/git.dart';
import 'package:github/github.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:version/version.dart';

import 'command.dart';
import 'helpers.dart';

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

    if (isValid) {
      if (hasNativeDependency(args.packageName)) {
        if (!await _validateiOSRelease(packagePath, args, logger)) {
          return false;
        }
        if (!await _validateAndroidRelease(packagePath, args, logger)) {
          return false;
        }
      }
    }

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
          '❌ We really should only release from `develop` or another `release` branch.');
      return false;
    }

    return true;
  }

  Future<bool> _validateiOSRelease(
      String packagePath, CommandArguments args, Logger logger) async {
    const githubOrganization = 'DataDog';
    const repoName = 'dd-sdk-ios';
    final repoSlug = RepositorySlug(githubOrganization, repoName);

    args.iOSRelease =
        await _validateReleaseVersion(repoSlug, 'iOS', args.iOSRelease, logger);
    return args.iOSRelease != null;
  }

  Future<bool> _validateAndroidRelease(
      String packagePath, CommandArguments args, Logger logger) async {
    const githubOrganization = 'DataDog';
    const repoName = 'dd-sdk-android';
    final repoSlug = RepositorySlug(githubOrganization, repoName);

    args.androidRelease = await _validateReleaseVersion(
        repoSlug, 'Android', args.androidRelease, logger);

    return args.androidRelease != null;
  }

  Future<String?> _validateReleaseVersion(
    RepositorySlug repoSlug,
    String platform,
    String? release,
    Logger logger,
  ) async {
    final githubToken = Platform.environment['GITHUB_TOKEN'];
    final github = GitHub(auth: Authentication.withToken(githubToken));

    // If we didn't specify a version get the current latest release from github.
    // If we did specify a release, check that it actually exists.
    if (release == null) {
      logger.fine('🌎 Fetching latest $platform release from github... ');
      final latestRelease =
          await github.repositories.getLatestRelease(repoSlug);
      logger.fine('ℹ️ Latest $platform release is ${latestRelease.name}');
      release = latestRelease.tagName;
    } else {
      try {
        final _ =
            await github.repositories.getReleaseByTagName(repoSlug, release);
      } on RepositoryNotFound {
        logger.shout(
            '❌ Could not find target $platform release $release. Please check the tag name');
        return null;
      }
    }

    logger.info('ℹ️ Releasing with $platform version $release.');

    logger.fine('🌎 Getting the difference between "$release" and "develop"');
    final compare =
        await github.repositories.compareCommits(repoSlug, release!, 'develop');

    while (true) {
      print(
          'Current $platform code on develop is ahead of $release by ${compare.aheadBy} commits.');
      print('Are you okay with this? ([Y]es, [N]o, [S]ee Changes: ');

      final input = stdin.readLineSync();
      if (input != null && input.isNotEmpty) {
        final firstChar = input[0].toLowerCase();
        if (firstChar == 'y') {
          break;
        } else if (firstChar == 'n') {
          logger.shout('😳 Oh, I\'m glad we stopped then!');
          return null;
        } else if (firstChar == 's') {
          if (compare.commits != null) {
            final nonMergeCommits = compare.commits!.where((commit) {
              final message = commit.commit?.message;
              return message != null && !message.startsWith('Merge');
            });

            if (nonMergeCommits.isNotEmpty) {
              for (final commit in nonMergeCommits) {
                var firstLine = commit.commit!.message!.split('\n').first;
                print('- $firstLine by ${commit.commit?.author?.name}');
              }
            } else {
              print('There are only merge commits.');
            }
          } else {
            print('There are no commits to see?');
          }
        }
      }
    }

    logger.fine('✅ Confirmed okay shipping with $platform release $release');
    return release;
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

    logger.info('ℹ️ Running `flutter pub publish --dry-run`');
    var process = await Process.start(
        'flutter', ['pub', 'publish', '--dry-run'],
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
