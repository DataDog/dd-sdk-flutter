// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

typedef OutputPipeHandler = void Function(String line);

Future<int> runProcess(String executable, List<String> args,
    {String? workingDirectory,
    OutputPipeHandler? stdout,
    OutputPipeHandler? stderr}) async {
  var process =
      await Process.start(executable, args, workingDirectory: workingDirectory);
  if (stdout != null) {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((event) {
      stdout(event);
    });
  }
  if (stderr != null) {
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((event) {
      stderr(event);
    });
  }

  return await process.exitCode;
}
