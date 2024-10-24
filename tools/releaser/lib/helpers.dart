// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

bool hasNativeDependency(String packageName) {
  return packageName == 'datadog_flutter_plugin' ||
      packageName == 'datadog_webview_tracking';
}

Future<GitDir?> getGitDir() async {
  final currentPath = path.current;

  if (!await GitDir.isGitDir(currentPath)) {
    Logger.root.shout('❌ Current directory is not a git directory.');
    return null;
  }

  return await GitDir.fromExisting(
    path.current,
    allowSubdirectory: true,
  );
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
    file.openWrite().write(newFileBuffer);
    logger.info(' ✏️ Wrote ${file.path}');
  }
}
