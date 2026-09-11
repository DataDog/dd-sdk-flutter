// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

// Keep this script runnable before `dart pub get` configures the package.
// ignore: avoid_relative_lib_imports
import '../lib/conventional_commit.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length == 2 && arguments[0] == '--subject') {
    final subject = arguments[1];
    if (isConventionalCommitSubject(subject)) {
      stdout.writeln('The commit subject uses the Conventional Commit format.');
      return;
    }

    _writeExpectedFormat(subject: subject);
    exitCode = 1;
    return;
  }

  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart tools/ci/bin/check_conventional_commits.dart '
      '<base revision> <head revision>',
    );
    stderr.writeln(
      '   or: dart tools/ci/bin/check_conventional_commits.dart '
      '--subject <commit subject>',
    );
    exitCode = 2;
    return;
  }

  final baseRevision = arguments[0];
  final headRevision = arguments[1];
  if (baseRevision.isEmpty || RegExp(r'^0+$').hasMatch(baseRevision)) {
    stderr.writeln('The base revision is not available.');
    exitCode = 2;
    return;
  }

  final result = await Process.run('git', [
    'log',
    '--no-merges',
    '--format=%H%x00%s',
    '$baseRevision..$headRevision',
  ]);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    exitCode = result.exitCode;
    return;
  }

  final invalidCommits = <({String sha, String subject})>[];
  for (final record in (result.stdout as String).split('\n')) {
    if (record.isEmpty) continue;

    final separator = record.indexOf('\x00');
    if (separator == -1) {
      stderr.writeln('Could not parse git log record: $record');
      exitCode = 2;
      return;
    }

    final sha = record.substring(0, separator);
    final subject = record.substring(separator + 1);
    if (!isConventionalCommitSubject(subject)) {
      invalidCommits.add((sha: sha, subject: subject));
    }
  }

  if (invalidCommits.isEmpty) {
    stdout.writeln('All non-merge commits use Conventional Commit subjects.');
    return;
  }

  stderr.writeln('These commits do not use Conventional Commit subjects:');
  for (final commit in invalidCommits) {
    stderr.writeln('  ${commit.sha.substring(0, 8)} ${commit.subject}');
  }
  _writeExpectedFormat();
  exitCode = 1;
}

void _writeExpectedFormat({String? subject}) {
  if (subject != null) {
    stderr.writeln('Invalid commit subject: $subject');
  }
  stderr.writeln();
  stderr.writeln('Expected: <type>[optional scope][!]: <description>');
  stderr.writeln('Example: feat(flags): add initialization timeout');
}
