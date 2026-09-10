// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';

import 'helpers.dart';

/// Inserts a new `## {version}` section at the top of [changelogFile],
/// above whatever's already there -- this repo's `CHANGELOG.md` convention
/// has no `## Unreleased` placeholder to replace, unlike the legacy
/// `generate_changelog.dart` path, so there's nothing to remove first.
///
/// [body] is the section's content (see `llm/changelog.dart`'s
/// `renderChangelogSection`) without the heading itself.
Future<void> prependChangelogSection(
  File changelogFile,
  String version,
  String body,
  Logger logger,
  bool dryRun,
) async {
  logger.info('ℹ️ Adding CHANGELOG.md section for $version');

  var wrote = false;
  await transformFile(changelogFile, logger, dryRun, (line) {
    if (!wrote) {
      wrote = true;
      return '## $version\n\n$body\n\n$line';
    }
    return line;
  });

  // An empty file (or one with no lines transformFile visits) never hits
  // the callback -- write the section directly rather than silently no-op.
  if (!wrote && !dryRun) {
    await changelogFile.writeAsString('## $version\n\n$body\n');
  }
}
