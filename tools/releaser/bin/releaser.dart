// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:releaser/cocoapod_util.dart';
import 'package:releaser/command.dart';
import 'package:releaser/generate_changelog.dart';
import 'package:releaser/git_actions.dart';
import 'package:releaser/gradle_util.dart';
import 'package:releaser/helpers.dart';
import 'package:releaser/release_validator.dart';
import 'package:releaser/version_updater.dart';
import 'package:releaser/yaml_util.dart';

void main(List<String> arguments) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((event) {
    print(event.message);
  });

  final argParser = ArgParser()
    ..addOption('version', abbr: 'v', mandatory: true)
    ..addFlag(
      'skip-git-checks',
      help: "Don't perform checks on branch names or un-staged files",
      defaultsTo: false,
    )
    ..addFlag(
      'skip-changelog-check',
      help:
          "Don't check if there are any items in the changelog (for debuging the releaser only)",
      defaultsTo: false,
    )
    ..addOption(
      'ios-version',
      help: 'Explicitly set the iOS release this release will target',
    )
    ..addOption(
      'android-version',
      help: 'Explicitly set the Android release this release will target',
    )
    ..addFlag(
      'dry-run',
      abbr: 'd',
      help: "Don't perform any actual operations. Also bypasses git checks",
      defaultsTo: false,
    )
    ..addFlag('verbose', defaultsTo: false)
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Print the help',
      negatable: false,
      defaultsTo: false,
    );

  ArgResults argResults;
  try {
    argResults = argParser.parse(arguments);
  } on FormatException catch (e) {
    print('❌ ${e.message}');
    _printUsage(argParser);
    return;
  }

  if (argResults['verbose']) {
    Logger.root.level = Level.FINEST;
  }

  if (argResults['help']) {
    _printUsage(argParser);
    return;
  }

  final commandArgs = await _validateArguments(argResults);
  if (commandArgs == null) {
    _printUsage(argParser);
    return;
  }

  final githubToken = Platform.environment['GITHUB_TOKEN'];
  if (githubToken == null) {
    Logger.root.shout(
        '❌ Must have the environment variable GITHUB_TOKEN set to validate native SDK releases.');
    return;
  }

  final currentBranch = await commandArgs.gitDir.currentBranch();
  final choreBranch =
      'chore/${commandArgs.packageName}/prep-v${commandArgs.version}';

  // By default (develop) increment the version by a minor version
  var versionBumpType = VersionBumpType.minor;
  // If we're on a release branch, bump by a revision
  if (currentBranch.branchName.contains('release')) {
    versionBumpType = VersionBumpType.rev;
  }
  // If we're releasing a pre-release, bump by pre-release
  if (commandArgs.version.contains('-')) {
    versionBumpType = VersionBumpType.prerelease;
  }

  final commands = <Command>[
    ValidateReleaseCommand(),
    CreateBranchCommand(choreBranch),
    GenerateChangelogCommand(),
    UpdateVersionsCommand(),
    CommitChangesCommand(
        'chore: Preparing for release of ${commandArgs.packageName} ${commandArgs.version}.'),
    CreateReleaseBranchCommand(),
    RemoveDependencyOverridesCommand(),
    RemovePodOverridesCommand(),
    UpdateGradleFilesCommand(),
    CommitChangesCommand(
      'chore: Remove dependency overrides for release of ${commandArgs.packageName} ${commandArgs.version}.',
      noChangesOkay: true,
    ),
    ValidatePublishDryRun(),
    SwitchBranchCommand(choreBranch),
    BumpVersionCommand(versionBumpType),
    CommitChangesCommand(
        'chore: Bump version of ${commandArgs.packageName} to next potential release.'),
  ];

  for (final command in commands) {
    if (!(await command.run(commandArgs, Logger.root))) {
      break;
    }
  }
}

Future<CommandArguments?> _validateArguments(ArgResults argResults) async {
  if (argResults.rest.isEmpty) {
    print('❌ A package name is required.');
    return null;
  }

  final packageName = argResults.rest.first;
  final version = argResults['version'];
  bool dryRun = argResults['dry-run'];
  bool skipGitChecks = argResults['skip-git-checks'];
  bool skipChangelogCheck = argResults['skip-changelog-check'];

  final gitDir = await getGitDir();
  if (gitDir == null) {
    return null;
  }

  return CommandArguments(
    packageName: packageName,
    packageRoot: path.join(gitDir.path, 'packages', packageName),
    gitDir: gitDir,
    skipGitChecks: skipGitChecks,
    skipChangelogCheck: skipChangelogCheck,
    version: version,
    iOSRelease: argResults['ios-version'],
    androidRelease: argResults['android-version'],
    dryRun: dryRun,
  );
}

void _printUsage(ArgParser argParser) {
  print('\nUsage: releaser.dart [package] [options]');
  print('\n${argParser.usage}');
}
