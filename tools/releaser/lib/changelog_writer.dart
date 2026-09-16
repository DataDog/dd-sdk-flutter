// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';

import 'helpers.dart';

/// Inserts a new `## {version}` section at the top of [changelogFile]'s
/// entries -- this repo's `CHANGELOG.md` convention has no `## Unreleased`
/// placeholder to replace, unlike the legacy `generate_changelog.dart` path,
/// so there's nothing to remove first. A leading `# Changelog` title (and any
/// blank lines around it) is preserved above the new section rather than
/// pushed below it.
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

  // `transformFile` reads via `openRead`, which throws on a missing file --
  // a package with no CHANGELOG.md yet should get one created, not crash
  // the whole run.
  if (!changelogFile.existsSync()) {
    logger.warning(
      '⚠️ ${changelogFile.path} does not exist, creating it now.',
    );
    if (!dryRun) {
      await changelogFile.writeAsString('## $version\n\n$body\n');
    }
    return;
  }

  var wrote = false;
  var titleChecked = false;
  await transformFile(changelogFile, logger, dryRun, (line) {
    if (wrote) return line;

    // Blank lines before the insertion point (leading, or between a
    // preserved title and the first entry) pass through unchanged.
    if (line.trim().isEmpty) {
      return line;
    }

    if (!titleChecked) {
      titleChecked = true;
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('# ') && !trimmed.startsWith('##')) {
        // Leading h1 title -- keep it above the new section.
        return line;
      }
    }

    wrote = true;
    return '## $version\n\n$body\n\n$line';
  });

  // An empty file (or one with no lines transformFile visits) never hits
  // the callback -- write the section directly rather than silently no-op.
  if (!wrote && !dryRun) {
    await changelogFile.writeAsString('## $version\n\n$body\n');
  }
}
