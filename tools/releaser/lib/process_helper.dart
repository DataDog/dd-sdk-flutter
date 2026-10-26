// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

typedef OutputPipeHandler = void Function(String line);

Future<int> runProcess(
  String executable,
  List<String> args, {
  String? workingDirectory,
  OutputPipeHandler? stdout,
  OutputPipeHandler? stderr,
}) async {
  var process = await Process.start(
    executable,
    args,
    workingDirectory: workingDirectory,
  );

  final stdoutDone = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .forEach(stdout ?? (_) {});
  final stderrDone = process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .forEach(stderr ?? (_) {});

  // exitCode can complete before the piped stdout/stderr streams finish
  // delivering their data, so wait for both before returning -- otherwise
  // callers building up a buffer from the pipe handlers can see truncated
  // output.
  final exitCode = await process.exitCode;
  await stdoutDone;
  await stderrDone;
  return exitCode;
}
