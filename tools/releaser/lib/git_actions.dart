// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:logging/logging.dart';

import 'command.dart';

class CreateChoreBranchCommand extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    final branchName = 'chore/${args.packageName}/release-${args.version}';
    logger.info('ℹ️ Creating branch $branchName');

    if (!args.dryRun) {
      var result = await args.gitDir.runCommand(['checkout', '-b', branchName]);

      if (result.exitCode != 0) {
        logger.shout('❌ Error creating branch:');
        logger.shout(result.stderr);
        return false;
      }
    }

    return true;
  }
}

class CommitChangesCommand extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    logger.info('ℹ️ Committing changes');
    if (!args.dryRun) {
      var result = await args.gitDir.runCommand([
        'add',
        '.',
      ]);
      if (result.exitCode != 0) {
        logger.shout('❌ Failed to stage: ${result.stderr}');
        return false;
      }
      result = await args.gitDir.runCommand([
        'commit',
        '-m',
        '🚀 Preparing for release of ${args.packageName} ${args.version}'
      ]);
      if (result.exitCode != 0) {
        logger.shout('❌ Failed to commit: ${result.stderr}');
        return false;
      }
    }
    return true;
  }
}
