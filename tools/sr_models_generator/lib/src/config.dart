// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The generator configuration, read from `sr_models_generator.yaml`.
class GeneratorConfig {
  GeneratorConfig({
    required this.file,
    required this.repository,
    required this.commit,
    required this.rootSchema,
    required this.output,
  });

  /// Reads and validates the configuration file at [path].
  factory GeneratorConfig.load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw ConfigException('Configuration file not found', path);
    }
    return GeneratorConfig.parse(file.readAsStringSync(), file: path);
  }

  /// Parses [source], the contents of the configuration file at [file].
  ///
  /// Relative paths in the configuration are resolved against the directory
  /// of [file].
  factory GeneratorConfig.parse(String source, {required String file}) {
    final Object? yaml;
    try {
      yaml = loadYaml(source);
    } on YamlException catch (e) {
      throw ConfigException('Invalid YAML: ${e.message}', file);
    }
    if (yaml is! YamlMap) {
      throw ConfigException('Expected a YAML map', file);
    }

    String readString(YamlMap map, String key, String path) {
      final value = map[key];
      if (value is! String || value.trim().isEmpty) {
        throw ConfigException('"$path" must be a non-empty string', file);
      }
      return value;
    }

    final rumEventsFormat = yaml['rum_events_format'];
    if (rumEventsFormat is! YamlMap) {
      throw ConfigException('"rum_events_format" must be a map', file);
    }
    final commit = readString(
      rumEventsFormat,
      'commit',
      'rum_events_format.commit',
    );
    _checkCommit(commit, file);

    return GeneratorConfig(
      file: file,
      repository: readString(
        rumEventsFormat,
        'repository',
        'rum_events_format.repository',
      ),
      commit: commit,
      rootSchema: readString(yaml, 'root_schema', 'root_schema'),
      output: p.normalize(
        p.join(p.dirname(file), readString(yaml, 'output', 'output')),
      ),
    );
  }

  /// Path of the configuration file this was read from.
  final String file;

  /// Git URL of rum-events-format.
  final String repository;

  /// Full SHA of the pinned rum-events-format commit.
  final String commit;

  /// Entry point of the schemas, relative to the rum-events-format root.
  final String rootSchema;

  /// Path of the generated file, resolved against the configuration's
  /// directory.
  final String output;

  /// Pins [sha] in the configuration file, keeping its comments and layout.
  void writeCommit(String sha) {
    final source = File(file).readAsStringSync();
    File(file).writeAsStringSync(replaceCommit(source, sha, file: file));
  }

  /// Returns [source] with the pinned commit replaced by [sha].
  ///
  /// Only the value of `rum_events_format.commit` changes, so comments and
  /// formatting are kept. The result is parsed again to make sure the edit
  /// changed the right key.
  static String replaceCommit(
    String source,
    String sha, {
    required String file,
  }) {
    _checkCommit(sha, file);
    final pattern = RegExp(
      r'^([ \t]+commit:[ \t]*)[0-9A-Za-z]+',
      multiLine: true,
    );
    final matches = pattern.allMatches(source).length;
    if (matches != 1) {
      throw ConfigException(
        'Expected exactly one "commit:" entry, found $matches',
        file,
      );
    }
    final updated = source.replaceFirstMapped(pattern, (m) => '${m[1]}$sha');
    if (GeneratorConfig.parse(updated, file: file).commit != sha) {
      throw ConfigException(
        'Could not update "rum_events_format.commit"',
        file,
      );
    }
    return updated;
  }

  /// The pin must be an exact commit, not a branch or tag that can move.
  static void _checkCommit(String commit, String file) {
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
      throw ConfigException(
        '"rum_events_format.commit" must be a full 40-character commit SHA, '
        'got "$commit"',
        file,
      );
    }
  }
}

/// The configuration file is missing or invalid.
class ConfigException implements Exception {
  ConfigException(this.message, this.file);

  final String message;
  final String file;

  @override
  String toString() => '$file: $message';
}
