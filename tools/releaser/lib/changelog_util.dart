// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';

import 'helpers.dart';

final _headingPattern = RegExp(r'^##\s+(.*?)\s*$');

/// Inserts a new `## {version}` section at the top of [changelogFile]'s
/// entries -- this repo's `CHANGELOG.md` convention has no `## Unreleased`
/// placeholder to replace, unlike the legacy `generate_changelog.dart` path,
/// so there's nothing to remove first. A leading `# Changelog` title (and any
/// blank lines around it) is preserved above the new section rather than
/// pushed below it.
///
/// If the topmost existing section is already headed `## $version` -- e.g. a
/// prior release-prep run wrote it but the release never actually shipped,
/// so pub.dev's latest is still behind it -- [body] is merged underneath
/// that existing heading instead of prepending a second, duplicate one.
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
    logger.warning('⚠️ ${changelogFile.path} does not exist, creating it now.');
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
    final existingHeading = _headingPattern.firstMatch(line)?.group(1);
    if (existingHeading == version) {
      logger.warning(
        '⚠️ $version already has a section in ${changelogFile.path} -- '
        'merging into it rather than adding a duplicate heading. This '
        'usually means that version was prepared before but never '
        'actually published.',
      );
      return '$line\n\n$body';
    }
    return '## $version\n\n$body\n\n$line';
  });

  // An empty file (or one with no lines transformFile visits) never hits
  // the callback -- write the section directly rather than silently no-op.
  if (!wrote && !dryRun) {
    await changelogFile.writeAsString('## $version\n\n$body\n');
  }
}

/// The body of [changelogFile]'s `## {version}` section (heading not
/// included), or `null` if that heading isn't present. The mirror-image
/// read of [prependChangelogSection] -- used by `publish_release.dart` to
/// source a `gh release create` body from the same section a reviewer
/// already read and approved in the release PR, rather than just linking
/// back to it.
String? extractChangelogSection(File changelogFile, String version) {
  if (!changelogFile.existsSync()) return null;

  final lines = changelogFile.readAsLinesSync();
  final startIndex = lines.indexWhere(
    (line) => _headingPattern.firstMatch(line)?.group(1) == version,
  );
  if (startIndex == -1) return null;

  final endIndex = lines.skip(startIndex + 1).toList().indexWhere(
    (line) => _headingPattern.hasMatch(line),
  );
  final sectionLines = endIndex == -1
      ? lines.sublist(startIndex + 1)
      : lines.sublist(startIndex + 1, startIndex + 1 + endIndex);

  // Trim leading/trailing blank lines the heading/next-heading spacing
  // leaves behind, but keep blank lines within the body itself.
  var start = 0;
  var end = sectionLines.length;
  while (start < end && sectionLines[start].trim().isEmpty) {
    start++;
  }
  while (end > start && sectionLines[end - 1].trim().isEmpty) {
    end--;
  }

  return sectionLines.sublist(start, end).join('\n');
}
