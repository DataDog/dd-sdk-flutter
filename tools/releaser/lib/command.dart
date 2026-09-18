// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:git/git.dart';
import 'package:logging/logging.dart';

class PackageRelease {
  final String name;
  final String version;

  PackageRelease({required this.name, required this.version});
}

class CommandArguments {
  // The list of packages to release
  final List<PackageRelease> packages;

  // The GitDir for the current repo
  final GitDir gitDir;

  // Skip git and branch checks during the validate step
  final bool skipGitChecks;

  // Skip changelog check
  final bool skipChangelogCheck;

  // The release of the iOS SDK we want this release to refer to
  String? iOSRelease;

  // The release of the Android SDK we want this release to refer to
  String? androidRelease;

  // Whether we're doing a dry run
  final bool dryRun;

  CommandArguments({
    required this.packages,
    required this.gitDir,
    required this.skipGitChecks,
    required this.skipChangelogCheck,
    required this.iOSRelease,
    required this.androidRelease,
    required this.dryRun,
  });
}

abstract class Command {
  Future<bool> run(CommandArguments args, Logger logger);
}
