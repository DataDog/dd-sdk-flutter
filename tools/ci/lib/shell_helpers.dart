// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

Future<String> shellRun(String command, List<String> args,
    {bool writeStdOut = false,
    Stream<List<int>>? stdIn,
    String? workingDirectory}) async {
  print("Running \$ $command ${args.join(' ')}");

  var process =
      await Process.start(command, args, workingDirectory: workingDirectory);
  var output = StringBuffer();
  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((event) {
    if (writeStdOut) {
      print(event);
    }
    output.writeln(event);
  });
  process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((event) {
    print(event);
  });
  if (stdIn != null) {
    process.stdin.addStream(stdIn);
  }

  var exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw Exception('shell command exited with non-zero exit code: $exitCode.');
  }

  return output.toString();
}
