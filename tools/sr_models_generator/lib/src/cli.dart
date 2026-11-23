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
/// generated models to the configured output. With `--check`, only tells
/// whether that output is up to date. With `--ref`, pins another commit
/// first, once the models of its schemas are generated.
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
  final ref = options.option('ref');
  final usageError = switch (ref) {
    '' => '--ref needs a branch, tag or SHA.',
    final _? when options.flag('check') =>
      '--ref and --check cannot be used together.',
    _ => null,
  };
  if (usageError != null) {
    err
      ..writeln(usageError)
      ..writeln()
      ..writeln(_usage(parser));
    return 64; // EX_USAGE
  }

  try {
    final config = GeneratorConfig.load(
      p.join(packageRoot, 'sr_models_generator.yaml'),
    );
    final cache = p.join(packageRoot, '.dart_tool', 'rum-events-format');
    final checkout = switch (ref ?? config.commit) {
      final sha when isFullCommitSha(sha) => await checkoutCommit(
        repository: config.repository,
        sha: sha,
        cacheDirectory: cache,
      ),
      final branchOrTag => await fetchLatest(
        repository: config.repository,
        branchOrTag: branchOrTag,
        cacheDirectory: cache,
      ),
    };
    final library = await generateLibrary(
      config,
      schemasRoot: checkout.directory,
      source: config.sourceUrl(checkout.commit),
    );
    final output = File(config.output);
    final schemas = 'rum-events-format ${checkout.commit.substring(0, 7)}';
    if (options.flag('check')) {
      return _check(output, library.code, schemas, out: out, err: err);
    }
    if (ref != null) {
      // Only now that the models of the new schemas are generated.
      config.writeCommit(checkout.commit);
      out.writeln(
        checkout.commit == config.commit
            ? 'rum-events-format stays pinned at '
                  '${checkout.commit.substring(0, 7)}.'
            : 'Pinned rum-events-format ${checkout.commit.substring(0, 7)}, '
                  'was ${config.commit.substring(0, 7)}.',
      );
    }
    output
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(library.code);
    out.writeln(
      'Wrote ${library.definitions.length} types to '
      '${p.relative(config.output)}, from $schemas.',
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

/// Whether [output] is [code], as generated from [schemas].
int _check(
  File output,
  String code,
  String schemas, {
  required StringSink out,
  required StringSink err,
}) {
  const regenerate =
      'Run `dart run sr_models_generator` in tools/sr_models_generator to '
      'generate it.';
  final path = p.relative(output.path);
  if (!output.existsSync()) {
    err.writeln('$path does not exist. $regenerate');
    return 1;
  }
  final expected = code.split('\n');
  final actual = output.readAsStringSync().split('\n');
  for (var line = 0; line < expected.length || line < actual.length; line++) {
    if (line >= expected.length ||
        line >= actual.length ||
        expected[line] != actual[line]) {
      err.writeln(
        '$path is not up to date with $schemas: it differs from line '
        '${line + 1}. $regenerate',
      );
      return 1;
    }
  }
  out.writeln('$path is up to date with $schemas.');
  return 0;
}

String _usage(ArgParser parser) =>
    'Generates the Dart Session Replay models from rum-events-format.\n'
    '\n'
    'Usage: dart run sr_models_generator [options]\n'
    '\n'
    '${parser.usage}';
