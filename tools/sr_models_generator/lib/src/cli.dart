// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'generator.dart';
import 'schema_node.dart';
import 'schema_source.dart';

/// Runs the generator as `dart run sr_models_generator [arguments]` does,
/// for the package at [packageRoot], and returns the exit code.
///
/// Reads `sr_models_generator.yaml` from [packageRoot], checks out the
/// pinned rum-events-format commit in its `.dart_tool/`, and writes the
/// generated models to the configured output.
Future<int> runGenerator(
  List<String> arguments, {
  required String packageRoot,
  StringSink? out,
  StringSink? err,
}) async {
  out ??= stdout;
  err ??= stderr;
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    );
  final ArgResults options;
  try {
    options = parser.parse(arguments);
  } on FormatException catch (e) {
    err
      ..writeln(e.message)
      ..writeln()
      ..writeln(_usage(parser));
    return 64; // EX_USAGE
  }
  if (options.flag('help')) {
    out.writeln(_usage(parser));
    return 0;
  }

  try {
    final config = GeneratorConfig.load(
      p.join(packageRoot, 'sr_models_generator.yaml'),
    );
    final checkout = await checkoutCommit(
      repository: config.repository,
      sha: config.commit,
      cacheDirectory: p.join(packageRoot, '.dart_tool', 'rum-events-format'),
    );
    final library = await generateLibrary(
      config,
      schemasRoot: checkout.directory,
      source: config.sourceUrl(checkout.commit),
    );
    File(config.output)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(library.code);
    out.writeln(
      'Wrote ${library.definitions.length} types to '
      '${p.relative(config.output)}, from rum-events-format '
      '${checkout.commit.substring(0, 7)}.',
    );
    return 0;
  } on ConfigException catch (e) {
    err.writeln(e);
  } on SchemaException catch (e) {
    err.writeln('Invalid schema: $e');
  } on SchemaFetchException catch (e) {
    err.writeln('Cannot get the schemas: $e');
  }
  return 1;
}

String _usage(ArgParser parser) =>
    'Generates the Dart Session Replay models from rum-events-format.\n'
    '\n'
    'Usage: dart run sr_models_generator [options]\n'
    '\n'
    '${parser.usage}';
