// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

// This command is used to pin / unpin to specific versions of the iOS / Android
// codebase while still using version overrides. This can be useful for ongoing
// development close to a release.

import 'dart:io';

import 'package:args/args.dart';
import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:releaser/cocoapod_util.dart';
import 'package:releaser/helpers.dart';

Future<int> main(List<String> arguments) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((event) {
    print(event.message);
  });

  final argParser = ArgParser()
    ..addOption('version', abbr: 'v')
    ..addOption('platform',
        abbr: 'p', allowed: ['ios', 'android'], mandatory: true)
    ..addOption('package', mandatory: true)
    ..addFlag(
      'remove',
      abbr: 'r',
      help: 'Remove the version pin and set back to develop / snapshots',
      negatable: false,
    );

  ArgResults argResults;
  try {
    argResults = argParser.parse(arguments);
  } on FormatException catch (e) {
    Logger.root.shout('❌ ${e.message}');
    _printUsage(argParser);
    exit(1);
  }

  if (argResults['remove'] != true && argResults['version'] == null) {
    Logger.root.shout('❌ Must specify a version or set --remove.');
    exit(1);
  }

  final gitDir = await getGitDir();
  if (gitDir == null) {
    Logger.root.shout('💥 Could not establish your current git directory.');
    exit(1);
  }

  final version = argResults['version'] as String?;
  final package = argResults['package'] as String;
  switch (argResults['platform']) {
    case 'ios':
      return await _pinIOS(gitDir, package, version);
    case 'android':
      return await _pinAndroid(gitDir, package, version);
  }

  Logger.root.shout('💥 Unknown platform!');
  return 1;
}

void _printUsage(ArgParser argParser) {
  print('\nUsage: pinner.dart [options]');
  print('\n${argParser.usage}');
}

Future<int> _pinIOS(GitDir gitDir, String package, String? version) async {
  final specDependencyPattern = RegExp(
      r"(?<ws>\s+)pod '(?<dependency>.+)', :git => '(?<git>[^']*?)', :(?<overrideType>\w+) => '(?<override>[^']*?)'");

  final versionString =
      version != null ? ":tag => '$version'" : ":branch => 'develop'";
  final podFile = '$package/ios/Podfile';

  final file = File(path.join(gitDir.path, podFile));
  if (!file.existsSync()) {
    Logger.root.shout('❌ Could not find file $podFile');
    return 1;
  }

  bool inOverride = false;
  await transformFile(file, Logger.root, false, (line) {
    if (inOverride) {
      if (line.startsWith(overridesEndPattern)) {
        inOverride = false;
      } else {
        final match = specDependencyPattern.firstMatch(line);
        if (match != null) {
          line =
              "${match.namedGroup('ws')}pod '${match.namedGroup('dependency')}', :git => '${match.namedGroup('git')}', $versionString";
        }
      }
    } else if (line.startsWith(overridesStartPattern)) {
      inOverride = true;
    }

    return line;
  });

  return 0;
}

Future<int> _pinAndroid(GitDir gitDir, String package, String? version) async {
  const versionPrefix = 'ext.datadog_version';
  final versionRegex = RegExp('$versionPrefix = "(.*)"');

  final gradleFile = '$package/android/build.gradle';
  final versionString = version ?? '1+';

  final file = File(path.join(gitDir.path, gradleFile));
  if (!file.existsSync()) {
    Logger.root.shout('❌ Could not find file $gradleFile');
    return 1;
  }

  await transformFile(file, Logger.root, false, (line) {
    final versionMatch = versionRegex.firstMatch(line);
    if (versionMatch != null) {
      final oldVersion = versionMatch.group(1);
      line = line.replaceFirst('$versionPrefix = "$oldVersion"',
          '$versionPrefix = "$versionString"');
    }

    return line;
  });

  return 0;
}
