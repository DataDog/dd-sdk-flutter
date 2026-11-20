// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

Future<void> main(List<String> arguments) async {
  final [logPath, executable, avd, ...flags] = arguments;
  final log = File(logPath).openWrite(mode: FileMode.append);
  try {
    log.writeln('\n[${_timestamp()}] Starting Android emulator $avd');
    final emulator = await Process.start(executable, [avd, ...flags]);
    await emulator.stdin.close();
    final output = [
      emulator.stdout.listen(log.add),
      emulator.stderr.listen(log.add),
    ];
    final outputDone = Future.wait(
      output.map((stream) => stream.asFuture<void>()),
    );
    final status = await emulator.exitCode;
    // Emulator subprocesses can keep the output pipes open after it exits.
    await outputDone.timeout(const Duration(seconds: 10), onTimeout: () => []);
    await Future.wait(output.map((stream) => stream.cancel()));

    // Dart returns a negative signal number when a process is killed.
    exitCode = status < 0 ? 128 - status : status;
    log.writeln(
      '\n[${_timestamp()}] Android emulator exited with status $exitCode',
    );
  } on ProcessException catch (error) {
    log.writeln(
      '\n[${_timestamp()}] Could not start Android emulator $avd: $error',
    );
    exitCode = 1;
  } finally {
    await log.close();
  }
}

String _timestamp() => DateTime.now().toUtc().toIso8601String();
