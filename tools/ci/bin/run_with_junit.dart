// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:ci_helpers/integration_test_runner.dart';
import 'package:path/path.dart' as path;

// Runs a command that emits a `--machine` / `--reporter json` test event stream
// and pipes it into `tojunit`, returning the command's own exit code rather than
// tojunit's. Unlike `command | tojunit`, this doesn't depend on the shell's
// pipefail support (cmd.exe has none), so it works the same on Windows as it
// does on bash.
//
// The raw event stream is also written next to the junit report as `.jsonl`,
// and failing tests, errors, and the exit code are printed to the console.
void _usageErrorAndExit(ArgParser parser, String message) {
  stderr
    ..writeln(message)
    ..writeln()
    ..writeln(
      'Usage: run_with_junit.dart --output <file> -- <command> [args...]',
    )
    ..writeln()
    ..writeln(parser.usage);
  exit(64);
}

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'output',
      abbr: 'o',
      mandatory: true,
      help: 'Path to write the junit XML report to',
    );

  ArgResults results;
  try {
    results = parser.parse(arguments);
  } on ArgParserException catch (e) {
    _usageErrorAndExit(parser, e.message);
    return;
  }

  if (!results.wasParsed('output')) {
    _usageErrorAndExit(parser, 'Missing mandatory option "output".');
    return;
  }
  final outputFile = results['output'] as String;
  final command = results.rest;
  if (command.isEmpty) {
    _usageErrorAndExit(parser, 'Missing command to run after --');
    return;
  }

  Directory(path.dirname(outputFile)).createSync(recursive: true);
  final eventLogFile = path.setExtension(outputFile, '.jsonl');
  final eventLog = File(eventLogFile).openWrite();

  print('${command.join(' ')} | tojunit --output $outputFile');
  // `flutter` and `tojunit` are both `.bat` shims on Windows, which Process.start
  // can't run directly without going through a shell.
  final testProcess = await Process.start(
    command.first,
    command.sublist(1),
    runInShell: Platform.isWindows,
  );
  final tojunitProcess = await Process.start('tojunit', [
    '--output',
    outputFile,
  ], runInShell: Platform.isWindows);
  tojunitProcess.stdout.drain<void>();
  tojunitProcess.stderr.drain<void>();
  // tojunit exiting early (for example, on output it can't parse) closes its
  // stdin; later writes must not mask the command's own exit code.
  tojunitProcess.stdin.done.ignore();

  testProcess.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(stderr.writeln);

  final tracker = TestEventTracker();
  final stdoutDone = testProcess.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .forEach((line) {
        eventLog.writeln(line);
        tojunitProcess.stdin.writeln(line);
        if (tracker.handleLine(line) case final message?) {
          print(message);
        } else if (!line.startsWith('{') && !line.startsWith('[')) {
          // Output that isn't a test event, such as a crash report.
          print(line);
        }
      });

  final testExitCode = await testProcess.exitCode;
  await stdoutDone;
  await eventLog.close();
  await tojunitProcess.stdin.close().catchError((_) {});
  final tojunitExitCode = await tojunitProcess.exitCode;
  if (tojunitExitCode != 0) {
    print('tojunit failed with exit code $tojunitExitCode for $outputFile');
  }

  if (testExitCode != 0) {
    print(
      '${command.first} exited with code $testExitCode'
      '${tracker.failures.isEmpty ? ' without reporting a failing test' : ''}'
      '; event log: $eventLogFile',
    );
  }

  exit(testExitCode);
}
