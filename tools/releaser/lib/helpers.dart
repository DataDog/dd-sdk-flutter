// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:version/version.dart';

import 'command.dart';

bool hasNativeDependency(String packageName) {
  return packageName == 'datadog_flutter_plugin' ||
      packageName == 'datadog_webview_tracking';
}

Future<GitDir?> getGitDir(String? root) async {
  final currentPath = root ?? path.current;

  if (!await GitDir.isGitDir(currentPath)) {
    Logger.root.shout('❌ Current directory is not a git directory.');
    return null;
  }

  return await GitDir.fromExisting(
    currentPath,
    allowSubdirectory: true,
  );
}

String getPackageRoot(CommandArguments args, PackageRelease package) {
  return path.join(args.gitDir.path, 'packages/${package.name}');
}

Future<void> transformFile(
  File file,
  Logger logger,
  bool dryRun,
  String? Function(String e) transformer,
) async {
  final newFileBuffer = StringBuffer();
  await file
      .openRead()
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .forEach((element) {
    final newValue = transformer(element);
    if (newValue != null) {
      newFileBuffer.writeln(newValue);
    }
  });

  final filename = path.basename(file.path);
  logger.finest(' ------- NEW  $filename CONTENTS ------');
  logger.finest(newFileBuffer.toString());
  if (!dryRun) {
    final sync = file.openWrite();
    sync.write(newFileBuffer);
    await sync.flush();
    logger.info(' ✏️ Wrote ${file.path}');
  }
}

bool validateVersionNumber(String versionNumber, Logger logger) {
  try {
    final _ = Version.parse(versionNumber);
    return true;
  } on FormatException {
    logger.shout(
        '❌ Version $versionNumber does not parse properly as a semantic version');
  }
  return false;
}
