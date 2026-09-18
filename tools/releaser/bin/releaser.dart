// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:releaser/cocoapod_util.dart';
import 'package:releaser/command.dart';
import 'package:releaser/generate_changelog.dart';
import 'package:releaser/git_actions.dart';
import 'package:releaser/github_cmd_wrapper.dart';
import 'package:releaser/gradle_util.dart';
import 'package:releaser/helpers.dart';
import 'package:releaser/release_validator.dart';
import 'package:releaser/spm_util.dart';
import 'package:releaser/version_updater.dart';
import 'package:releaser/yaml_util.dart';

void main(List<String> arguments) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((event) {
    print(event.message);
  });

  final argParser = ArgParser()
    ..addOption('packages',
        help: 'A comma separated list of package:version pairs to release.')
    ..addOption('version', abbr: 'v')
    ..addOption('repo-root', help: 'The root of the repo to release from')
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

  CommandArguments? commandArgs;
  try {
    commandArgs = await _validateArguments(argResults, Logger.root);
  } catch (e) {
    print('❌ Error parsing command arguments.');
  }

  if (commandArgs == null) {
    _printUsage(argParser);
    return;
  }

  final gh = GithubCommandWrapper(commandArgs.gitDir.path);
  if (!await gh.checkAuth(Logger.root)) {
    print(
      '❌ Could not validate your authentication with the gh command line tool. Please login with `gh auth login`.',
    );
    return;
  }

  final currentBranch = await commandArgs.gitDir.currentBranch();
  final choreBranch = commandArgs.packages.length == 1
      ? 'chore/${commandArgs.packages.first.name}/prep-v${commandArgs.packages.first.version}'
      : 'chore/multi-package-release';

  // By default (develop) increment the version by a minor version
  var versionBumpType = VersionBumpType.minor;
  // If we're on a release branch, bump by a revision
  if (currentBranch.branchName.contains('release')) {
    versionBumpType = VersionBumpType.rev;
  }
  // If we're releasing a pre-release, bump by pre-release
  // if (commandArgs.version.contains('-')) {
  //   versionBumpType = VersionBumpType.prerelease;
  // }

  // If there are any initial releases, having no changes on the chore branch is okay (though unlikely)
  final isInitialRelease =
      commandArgs.packages.where((e) => e.version == '1.0.0').isNotEmpty;

  final commitPackageName = commandArgs.packages.length == 1
      ? '${commandArgs.packages.first.name} ${commandArgs.packages.first.version}'
      : 'multiple packages';

  String? commitBody;
  if (commandArgs.packages.length > 1) {
    commitBody = 'Releasing the following packages:\n';
    commitBody += [
      for (final package in commandArgs.packages)
        ' - ${package.name} ${package.version}'
    ].join('\n');
  }

  final commands = <Command>[
    ValidateReleaseCommand(),
    CreateBranchCommand(choreBranch),
    GenerateChangelogCommand(),
    UpdateVersionsCommand(),
    CommitChangesCommand(
      'chore: Preparing for release of $commitPackageName.',
      commitBody: commitBody,
      noChangesOkay: isInitialRelease,
    ),
    // Create a temporary branch to potentially hold multiple release branches
    CreateBranchCommand('release/temp'),
    RemoveDependencyOverridesCommand(),
    PinCocoapodsVersionCommand(),
    PinSwiftPackageVersion(),
    UpdateGradleFilesCommand(),
    CommitChangesCommand(
      'chore: Remove dependency overrides for release of $commitPackageName.',
      commitBody: commitBody,
      noChangesOkay: true,
    ),
    ValidatePublishDryRun(),
    for (final package in commandArgs.packages)
      CreateBranchCommand('release/${package.name}/v${package.version}'),
    DeleteBranchCommand('release/temp'),
    SwitchBranchCommand(choreBranch),
    BumpVersionCommand(versionBumpType),
    CommitChangesCommand(
      'chore: Bump versions of $commitPackageName to next potential release.',
      commitBody: commitBody,
    ),
  ];

  for (final command in commands) {
    if (!(await command.run(commandArgs, Logger.root))) {
      break;
    }
  }
}

Future<CommandArguments?> _validateArguments(
    ArgResults argResults, Logger logger) async {
  var packages = _parsePackages(argResults['packages'], logger);
  if (packages == null) {
    if (argResults.rest.isEmpty) {
      logger.shout('❌ A package name is required, or use "--packages"');
      return null;
    }

    if (argResults['version'] == null) {
      logger.shout('❌ Version is required when releasing a single package');
    }

    final packageName = argResults.rest.first;
    final version = argResults['version'];
    if (!validateVersionNumber(version, logger)) {
      return null;
    }

    packages = [PackageRelease(name: packageName, version: version)];
  }

  bool dryRun = argResults['dry-run'];
  bool skipGitChecks = argResults['skip-git-checks'];
  bool skipChangelogCheck = argResults['skip-changelog-check'];

  final root = argResults['repo-root'];

  final gitDir = await getGitDir(root);
  if (gitDir == null) {
    return null;
  }

  return CommandArguments(
    packages: packages,
    gitDir: gitDir,
    skipGitChecks: skipGitChecks,
    skipChangelogCheck: skipChangelogCheck,
    iOSRelease: argResults['ios-version'],
    androidRelease: argResults['android-version'],
    dryRun: dryRun,
  );
}

void _printUsage(ArgParser argParser) {
  print('\nUsage: releaser.dart [package] [options]');
  print('\n${argParser.usage}');
}

List<PackageRelease>? _parsePackages(String? packages, Logger logger) {
  if (packages == null) return null;

  var packageList = packages.split(',').map((e) {
    final colonIndex = e.indexOf(':');
    if (colonIndex < 0) {
      logger.shout(
          '❌ Invalid package specification $e. Missing : to specify version.');
      throw Error();
    }

    final packageName = e.substring(0, colonIndex).trim();
    final packageVersion = e.substring(colonIndex + 1).trim();

    if (!validateVersionNumber(packageVersion, logger)) {
      throw Error();
    }

    return PackageRelease(name: packageName, version: packageVersion);
  }).toList();

  return packageList;
}
