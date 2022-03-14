// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:git/git.dart';
import 'package:logging/logging.dart';

class CommandArguments {
  // The name of the packge we're releasing
  final String packageName;

  // The path to the root of the package
  final String packageRoot;

  // The GitDir for the current repo
  final GitDir gitDir;

  // Skip git and branch checks during the validate step
  final bool skipGitChecks;

  // Whether to commit changes and push them to github
  final bool commitChanges;

  // The version we're releasing
  final String version;

  // Whether we're doing a dry run
  final bool dryRun;

  CommandArguments({
    required this.packageName,
    required this.packageRoot,
    required this.gitDir,
    required this.skipGitChecks,
    required this.commitChanges,
    required this.version,
    required this.dryRun,
  });
}

abstract class Command {
  Future<bool> run(CommandArguments args, Logger logger);
}
