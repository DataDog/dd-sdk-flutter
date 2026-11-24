// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

import 'package:args/args.dart';
import 'package:sr_models_generator/sr_models_generator.dart';

final _parser = ArgParser()
  ..addFlag(
    'help',
    abbr: 'h',
    negatable: false,
    help: 'Print this usage information.',
  )
  ..addFlag(
    'check',
    negatable: false,
    help:
        'Fail if the generated models are not up to date with the pinned '
        'schemas, without writing them.',
  )
  ..addOption(
    'ref',
    valueHelp: 'branch, tag or SHA',
    help:
        'Pin this rum-events-format commit, or the one this branch or tag '
        'points to now, and generate the models of its schemas.',
  );

/// The usage information `--help` prints.
final usage =
    'Generates the Dart Session Replay models from rum-events-format.\n'
    '\n'
    'Usage: dart run sr_models_generator [options]\n'
    '\n'
    '${_parser.usage}';

/// The generator options in [arguments], or null with `--help`.
///
/// Throws a [FormatException] when the arguments are invalid.
GeneratorOptions? parseArguments(List<String> arguments) {
  final results = _parser.parse(arguments);
  if (results.flag('help')) return null;
  final check = results.flag('check');
  final ref = results.option('ref');
  return switch (ref) {
    '' => throw const FormatException('--ref needs a branch, tag or SHA.'),
    _? when check => throw const FormatException(
      '--ref and --check cannot be used together.',
    ),
    _ => (check: check, ref: ref),
  };
}

Future<void> main(List<String> arguments) async {
  final GeneratorOptions? options;
  try {
    options = parseArguments(arguments);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln()
      ..writeln(usage);
    exitCode = 64; // EX_USAGE
    return;
  }
  if (options == null) {
    stdout.writeln(usage);
    return;
  }
  if (!File(configFileName).existsSync()) {
    stderr.writeln(
      'No $configFileName in the current directory. Run sr_models_generator '
      'from tools/sr_models_generator.',
    );
    exitCode = 64; // EX_USAGE
    return;
  }
  exitCode = await runGenerator(options, directory: Directory.current.path);
}
