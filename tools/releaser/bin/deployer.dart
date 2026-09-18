// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:releaser/github_cmd_wrapper.dart';
import 'package:releaser/helpers.dart';

class ReleaseInfo {
  final String commitSha;
  final String package;
  final String version;
  final String changeLog;

  ReleaseInfo(
    this.commitSha,
    this.package,
    this.version,
    this.changeLog,
  );
}

void main(List<String> arguments) async {
  Logger.root.level = Level.FINEST;
  Logger.root.onRecord.listen((event) {
    print(event.message);
  });

  final argParser = ArgParser()
    ..addOption('repo-root', help: 'The root of the repo to release from')
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

  if (argResults.rest.isEmpty) {
    Logger.root.shout('❌ Package name to deploy is required.');
    exit(1);
  }

  final root = argResults['repo-root'];
  final gitDir = await getGitDir(root);
  if (gitDir == null) {
    Logger.root.shout('💥 Could not establish your current git directory.');
    exit(1);
  }

  final github = GithubCommandWrapper(gitDir.path);
  if (!await github.checkAuth(Logger.root)) {
    Logger.root
        .shout('❌ Could not auth with `gh` command. Run `gh auth login`.');
    exit(1);
  }

  var packageName = arguments.first;
  if (!(await _validateBranchState(gitDir))) exit(1);

  final releaseInfo = await _getReleaseInfo(gitDir, packageName);
  if (releaseInfo == null) {
    Logger.root.shout('💥 Could not determine information about this release.');
    exit(1);
  }

  if (!await _performGitHubRelease(gitDir, releaseInfo)) {
    exit(1);
  }
}

Future<bool> _performGitHubRelease(
    GitDir gitDir, ReleaseInfo releaseInfo) async {
  final tag = '${releaseInfo.package}/v${releaseInfo.version}';
  Logger.root.fine('ℹ️ Creating tag $tag');
  await gitDir.runCommand(
      ['tag', '-a', tag, '-m', '🏷 Tag created by deploy.dart for $tag']);
  Logger.root.fine('ℹ️ Pushing to origin');
  await gitDir.runCommand(['push', 'origin', tag]);

  var github = GithubCommandWrapper(gitDir.path);

  Logger.root.fine('ℹ️ Creating github release for $tag');
  try {
    await github.createRelease(
      Logger.root,
      tag,
      '${releaseInfo.package} ${releaseInfo.version}',
      releaseInfo.changeLog,
      releaseInfo.version.contains('-'),
    );
  } catch (e) {
    Logger.root.shout('❌ Failed to create release: ${e.toString()}');
    return false;
  }

  return true;
}

Future<bool> _validateBranchState(GitDir gitDir) async {
  // Don't allow unstaged changes
  if (!await gitDir.isWorkingTreeClean()) {
    Logger.root.shout('❌ Working tree is not clean.');
    return false;
  }

  // Only allow deploy from main or a release/* branch
  final currentBranch = await gitDir.currentBranch();
  if (!(currentBranch.branchName == 'main' ||
      currentBranch.branchName.startsWith('release'))) {
    Logger.root
        .shout('❌ Only deploy releases from `main` or a `release` branch.');
    return false;
  }

  return true;
}

Future<ReleaseInfo?> _getReleaseInfo(GitDir gitDir, String packageName) async {
  final currentBranch = await gitDir.currentBranch();
  await gitDir.commitFromRevision(currentBranch.sha);

  final pubspecVersionRegex = RegExp(r'^version\: (?<version>.*)');

  // Validate against the pubspec
  var pubspecFile = File('${gitDir.path}/packages/$packageName/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    Logger.root.shout('❌ Could not find pubspec for `$packageName`.');
    return null;
  }

  String? pubspecVersion;
  await pubspecFile
      .openRead()
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .forEach((element) {
    final match = pubspecVersionRegex.firstMatch(element);
    if (match != null) {
      pubspecVersion = match.namedGroup('version');
    }
  });

  if (pubspecVersion == null) {
    Logger.root.shout('Version in pubspec is missing!');
    return null;
  }

  var changelogFile = File('${gitDir.path}/packages/$packageName/CHANGELOG.md');
  if (!changelogFile.existsSync()) {
    Logger.root.shout('❌ Could not find CHANGELOG.md for `$packageName`.');
    return null;
  }

  final changeLog = StringBuffer();
  bool foundVersion = false;
  await changelogFile
      .openRead()
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .forEach((line) {
    if (foundVersion) {
      if (line.startsWith('##')) {
        // Reached the end of the version
        foundVersion = false;
      } else if (line.trim().isNotEmpty) {
        changeLog.writeln(line);
      }
    } else if (line == '## $pubspecVersion') {
      foundVersion = true;
    }
  });

  return ReleaseInfo(
    currentBranch.sha,
    packageName,
    pubspecVersion!,
    changeLog.toString(),
  );
}

void _printUsage(ArgParser argParser) {
  print('\nUsage: releaser.dart [package] [options]');
  print('\n${argParser.usage}');
}
