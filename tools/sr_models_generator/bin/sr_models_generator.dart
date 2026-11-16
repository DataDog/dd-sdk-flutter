// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

import 'package:args/args.dart';

ArgParser _buildParser() {
  return ArgParser()..addFlag(
    'help',
    abbr: 'h',
    negatable: false,
    help: 'Print this usage information.',
  );
}

String _usage(ArgParser parser) {
  return 'Generates the Dart Session Replay models from rum-events-format.\n'
      '\n'
      'Usage: dart run sr_models_generator [options]\n'
      '\n'
      '${parser.usage}';
}

void main(List<String> arguments) {
  final parser = _buildParser();

  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln()
      ..writeln(_usage(parser));
    exitCode = 64; // EX_USAGE
    return;
  }

  if (results.flag('help')) {
    stdout.writeln(_usage(parser));
    exitCode = 0;
    return;
  }

  stderr.writeln('Model generation is not implemented yet.');
  exitCode = 1;
}
