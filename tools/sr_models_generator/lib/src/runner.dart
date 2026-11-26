// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as p;

import 'config.dart';
import 'generator.dart';
import 'schema_node.dart';
import 'schema_source.dart';

/// The name of the configuration file, in the directory the generator
/// runs from.
const configFileName = 'sr_models_generator.yaml';

/// What to generate: with `check`, only tell whether the generated models
/// are up to date; with `ref` (a branch, tag or SHA), pin another
/// rum-events-format commit first.
typedef GeneratorOptions = ({bool check, String? ref});

/// Generates the models configured in [directory]'s `sr_models_generator.yaml`
/// as [options] say, and returns the exit code.
///
/// The pinned rum-events-format commit is checked out in [directory]'s
/// `.tmp/`, and the generated models, and the samples if configured, are
/// written to the configured outputs.
/// With `ref`, its commit is pinned once the models of its schemas are
/// generated.
Future<int> runGenerator(
  GeneratorOptions options, {
  required String directory,
  StringSink? out,
  StringSink? err,
}) async {
  out ??= stdout;
  err ??= stderr;
  final (:check, :ref) = options;
  try {
    final config = GeneratorConfig.load(p.join(directory, configFileName));
    final cache = p.join(directory, '.tmp', 'rum-events-format');
    final checkout = switch (ref ?? config.commit) {
      final sha when isFullCommitSha(sha) => await checkoutCommit(
        repository: config.repository,
        sha: sha,
        cacheDirectory: cache,
        progress: out.writeln,
      ),
      final branchOrTag => await fetchLatest(
        repository: config.repository,
        branchOrTag: branchOrTag,
        cacheDirectory: cache,
        progress: out.writeln,
      ),
    };
    final library = await generateLibrary(
      config,
      schemasRoot: checkout.directory,
      source: config.sourceUrl(checkout.commit),
    );
    final samples = switch (config.samples) {
      final samples? => (
        await generateSamples(
          p.join(checkout.directory, samples.directory),
          destination: samples.output,
          source: '${config.sourceUrl(checkout.commit)}/${samples.directory}',
        ),
        File(samples.output),
      ),
      null => null,
    };
    final output = File(config.output);
    final schemas = 'rum-events-format ${checkout.commit.substring(0, 7)}';
    if (check) {
      final results = [
        _check(output, library.code, schemas, out: out, err: err),
        if (samples case (final generated, final file))
          _check(file, generated.code, schemas, out: out, err: err),
      ];
      return results.every((result) => result == 0) ? 0 : 1;
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
    if (samples case (final generated, final file)) {
      file
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(generated.code);
      out.writeln(
        'Wrote ${generated.count} samples to ${p.relative(file.path)}, '
        'from $schemas.',
      );
    }
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

/// The exit code telling whether [output] is [code], as generated from
/// [schemas]: 0 when it is, 1 otherwise.
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
