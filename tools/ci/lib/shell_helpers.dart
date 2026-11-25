// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Runs [command] and returns its stdout.
///
/// Throws if it exits non-zero, or, when [timeout] is set, if it is still
/// running after that long, in which case it is killed.
Future<String> shellRun(String command, List<String> args,
    {bool writeStdOut = false,
    Stream<List<int>>? stdIn,
    String? workingDirectory,
    Duration? timeout}) async {
  print("Running \$ $command ${args.join(' ')}");

  var process =
      await Process.start(command, args, workingDirectory: workingDirectory);
  var output = StringBuffer();
  final stdoutDone = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .forEach((event) {
    if (writeStdOut) {
      print(event);
    }
    output.writeln(event);
  });
  final stderrDone = process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .forEach((event) {
    print(event);
  });
  if (stdIn != null) {
    process.stdin.addStream(stdIn);
  }

  var exitCode = await (timeout == null
      ? process.exitCode
      : process.exitCode.timeout(timeout, onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          throw TimeoutException('$command timed out', timeout);
        }));
  // Child processes can keep the pipes open after the command exits, so don't
  // wait on them indefinitely for the last lines of output.
  await Future.wait([stdoutDone, stderrDone])
      .timeout(const Duration(seconds: 10), onTimeout: () => []);
  if (exitCode != 0) {
    throw Exception('shell command exited with non-zero exit code: $exitCode.');
  }

  return output.toString();
}
