// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:releaser/command.dart';
import 'package:releaser/git_actions.dart';
import 'package:releaser/helpers.dart';
import 'package:releaser/release_validator.dart';
import 'package:releaser/version_updater.dart';

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
      'no-commit',
      help: "Don't commit or push changes",
      defaultsTo: false,
    )
    ..addFlag(
      'dry-run',
      abbr: 'd',
      help: "Don't perform any actual operations. Also bypasses git checks",
      defaultsTo: false,
    )
    ..addFlag('verbose', defaultsTo: false)
    ..addOption(
      'branch',
      abbr: 'b',
      help: 'The branch to merge into. Defaults to `develop`',
    )
    ..addFlag(
      'no-main',
      help: 'Do not submit a pull request into main',
      negatable: false,
    )
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

  final commands = <Command>[
    ValidateReleaseCommand(),
    CreateChoreBranchCommand(),
    UpdateVersionsCommand(),
    ValidatePublishDryRun(),
    if (commandArgs.commitChanges) ...[
      CommitChangesCommand(),
    ]
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
  bool commitChanges = !argResults['no-commit'];

  final gitDir = await getGitDir();
  if (gitDir == null) {
    return null;
  }

  return CommandArguments(
    packageName: packageName,
    packageRoot: path.join(gitDir.path, 'packages', packageName),
    gitDir: gitDir,
    skipGitChecks: skipGitChecks,
    commitChanges: commitChanges,
    version: version,
    dryRun: dryRun,
  );
}

void _printUsage(ArgParser argParser) {
  print('\nUsage: releaser.dart [package] [options]');
  print('\n${argParser.usage}');
}
