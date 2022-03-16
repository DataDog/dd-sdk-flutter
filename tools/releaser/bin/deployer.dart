// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:git/git.dart';
import 'package:github/github.dart';
import 'package:logging/logging.dart';
import 'package:releaser/helpers.dart';

class ReleaseInfo {
  final String commitSha;
  final String package;
  final String version;

  ReleaseInfo(this.commitSha, this.package, this.version);
}

void main(List<String> arguments) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((event) {
    print(event.message);
  });

  final gitDir = await getGitDir();
  if (gitDir == null) {
    Logger.root.shout('💥 Could not establish your current git directory.');
    exit(1);
  }

  if (!(await _validateBranchState(gitDir))) exit(1);

  final releaseInfo = await _getReleaseInfo(gitDir);
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
  const githubOrganization = 'DataDog';
  const repoName = 'dd-sdk-flutter';

  final tag = '${releaseInfo.package}/v${releaseInfo.version}';
  Logger.root.fine('Creating tag $tag');
  await gitDir.runCommand(
      ['tag', '-a', tag, '-m', '🏷 Tag created by deploy.dart for $tag']);
  Logger.root.fine('Pushing to origin');
  await gitDir.runCommand(['push']);

  var github = GitHub(auth: findAuthenticationFromEnvironment());

  var createRelease = CreateRelease.from(
    tagName: tag,
    name: '${releaseInfo.package} ${releaseInfo.version}',
    targetCommitish: releaseInfo.commitSha,
    isDraft: true,
    isPrerelease: releaseInfo.version.contains('-'),
  );
  await github.repositories.createRelease(
      RepositorySlug(githubOrganization, repoName), createRelease);

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

Future<ReleaseInfo?> _getReleaseInfo(GitDir gitDir) async {
  final currentBranch = await gitDir.currentBranch();
  final currentCommit = await gitDir.commitFromRevision(currentBranch.sha);

  final releaseCommitRegex = RegExp(
      r'🚀 Prepping for release of (?<package>[a-z0-9_]+) (?<version>(.*))$');
  final pubspecVersionRegex = RegExp(r'^version\: (?<version>.*)');

  final match = releaseCommitRegex.firstMatch(currentCommit.message);
  if (match == null) {
    Logger.root.shout('❌ Current commit is not a prep for release.');
    return null;
  }

  final packageName = match.namedGroup('package');
  final packageVersion = match.namedGroup('version');

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

  if (pubspecVersion != packageVersion) {
    Logger.root.shout(
        'Version in pubspec does not match commit message! ($pubspecVersion vs. $packageVersion)');
    return null;
  }

  return ReleaseInfo(currentBranch.sha, packageName!, packageVersion!);
}
