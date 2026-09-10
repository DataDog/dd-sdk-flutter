// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

Future<GitDir?> getGitDir(String? root) async {
  final currentPath = root ?? path.current;

  if (!await GitDir.isGitDir(currentPath)) {
    Logger.root.shout('❌ Current directory is not a git directory.');
    return null;
  }

  return await GitDir.fromExisting(currentPath, allowSubdirectory: true);
}
