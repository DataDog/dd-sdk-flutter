// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:logging/logging.dart';

import 'command.dart';

class CreateBranchCommand extends Command {
  String branchName;

  CreateBranchCommand(this.branchName);

  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
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

class CreateReleaseBranchCommand extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    final branchName = 'release/${args.packageName}/v${args.version}';
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
  final String commitMessage;
  final bool noChangesOkay;

  CommitChangesCommand(this.commitMessage, {this.noChangesOkay = false});

  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    bool noChanges = await args.gitDir.isWorkingTreeClean();
    if (noChanges) {
      if (noChangesOkay) {
        logger.info('⏩ Skipping commit due to no changes. This is okay.');
        return true;
      } else if (!args.dryRun) {
        logger.shout(
            '❌ No changes from previous command. This is probably not expected.');
        return false;
      }
    }

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
      result = await args.gitDir.runCommand(['commit', '-m', commitMessage]);
      if (result.exitCode != 0) {
        logger.shout('❌ Failed to commit: ${result.stderr}');
        return false;
      }
    }
    return true;
  }
}

class SwitchBranchCommand extends Command {
  final String branch;

  SwitchBranchCommand(this.branch);

  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    logger.info('ℹ️ Switching to branch $branch');
    if (!args.dryRun) {
      var result = await args.gitDir.runCommand([
        'checkout',
        branch,
      ]);
      if (result.exitCode != 0) {
        logger.shout('❌ Failed to checkout branch $branch: ${result.stderr}');
        return false;
      }
    }
    return true;
  }
}
