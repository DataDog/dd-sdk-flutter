// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'resolver.dart';
import 'schema_source.dart';

/// The generator configuration, read from `sr_models_generator.yaml`.
@immutable
final class GeneratorConfig {
  GeneratorConfig({
    required this.file,
    required this.repository,
    required this.commit,
    required this.rootSchemas,
    required this.output,
    this.localSchemas,
    this.naming = const NamingOptions(),
  });

  /// The folder under which the schemas of [localSchemas] appear to the
  /// rum-events-format schemas, e.g. `flutter/enriched-record-schema.json`.
  static const localSchemasFolder = 'flutter';

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

    bool isNonEmptyString(Object? value) =>
        value is String && value.trim().isNotEmpty;

    List<String>? readStrings(YamlMap map, String key) {
      final value = map[key];
      if (value == null) return null;
      if (value is! YamlList || !value.every(isNonEmptyString)) {
        throw ConfigException(
          '"$key" must be a list of non-empty strings',
          file,
        );
      }
      return value.whereType<String>().toList();
    }

    Map<String, String>? readRenames(YamlMap map) {
      final value = map['type_renames'];
      if (value == null) return null;
      if (value is! YamlMap ||
          !value.keys.every(isNonEmptyString) ||
          !value.values.every(isNonEmptyString)) {
        throw ConfigException(
          '"type_renames" must map non-empty strings to non-empty strings',
          file,
        );
      }
      return {
        for (final entry in value.entries)
          if (entry case MapEntry(
            key: final String from,
            value: final String to,
          ))
            from: to,
      };
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
    commit.checkIsFullCommitSha(file: file);

    return GeneratorConfig(
      file: file,
      repository: readString(
        rumEventsFormat,
        'repository',
        'rum_events_format.repository',
      ),
      commit: commit,
      rootSchemas: switch (readStrings(yaml, 'root_schemas')) {
        final schemas? when schemas.isNotEmpty => schemas,
        _ => throw ConfigException(
          '"root_schemas" must be a non-empty list of non-empty strings',
          file,
        ),
      },
      localSchemas: switch (yaml['local_schemas']) {
        null => null,
        final String path when path.trim().isNotEmpty => _directory(
          p.normalize(p.join(p.dirname(file), path)),
          file,
        ),
        _ => throw ConfigException(
          '"local_schemas" must be a non-empty string',
          file,
        ),
      },
      output: p.normalize(
        p.join(p.dirname(file), readString(yaml, 'output', 'output')),
      ),
      naming: NamingOptions(
        typePrefix: yaml.containsKey('type_prefix')
            ? readString(yaml, 'type_prefix', 'type_prefix')
            : const NamingOptions().typePrefix,
        stripFromTitles:
            readStrings(yaml, 'strip_from_titles') ??
            const NamingOptions().stripFromTitles,
        renames: readRenames(yaml) ?? const NamingOptions().renames,
      ),
    );
  }

  /// Path of the configuration file this was read from.
  final String file;

  /// Git URL of rum-events-format.
  final String repository;

  /// Full SHA of the pinned rum-events-format commit.
  final String commit;

  /// Entry points of the schemas, relative to the rum-events-format root;
  /// the schemas of [localSchemas] are under [localSchemasFolder].
  final List<String> rootSchemas;

  /// The directory of the schemas kept in this repository, resolved
  /// against the configuration's directory, if any.
  final String? localSchemas;

  /// The `mounts` of a `SchemaLoader` that makes [localSchemas] available.
  Map<String, String> get schemaMounts => {localSchemasFolder: ?localSchemas};

  /// Path of the generated file, resolved against the configuration's
  /// directory.
  final String output;

  /// How generated types are named; each setting defaults to
  /// [NamingOptions]'s when the file does not set it.
  final NamingOptions naming;

  /// Browsable URL of the schemas at [commit], e.g.
  /// `https://github.com/DataDog/rum-events-format/tree/<commit>`.
  String sourceUrl(String commit) =>
      '${repository.replaceFirst(RegExp(r'\.git$'), '')}/tree/$commit';

  /// Pins [sha] in the configuration file, keeping its comments and layout.
  void writeCommit(String sha) {
    final source = File(file).readAsStringSync();
    File(file).writeAsStringSync(replaceCommit(source, sha, file: file));
  }

  /// Returns [source] with the pinned commit replaced by [sha], keeping
  /// its comments and layout.
  static String replaceCommit(
    String source,
    String sha, {
    required String file,
  }) {
    sha.checkIsFullCommitSha(file: file);
    return (YamlEditor(
      source,
    )..update(['rum_events_format', 'commit'], sha)).toString();
  }
}

/// [path], when it is an existing directory.
String _directory(String path, String file) {
  if (!Directory(path).existsSync()) {
    throw ConfigException('"local_schemas" is not a directory: $path', file);
  }
  return path;
}

extension on String {
  /// The pin must be an exact commit, not a branch or tag that can move.
  void checkIsFullCommitSha({required String file}) {
    if (!isFullCommitSha(this)) {
      throw ConfigException(
        '"rum_events_format.commit" must be a full 40-character commit SHA, '
        'got "$this"',
        file,
      );
    }
  }
}

/// The configuration file is missing or invalid.
@immutable
final class ConfigException implements Exception {
  ConfigException(this.message, this.file);

  final String message;
  final String file;

  @override
  String toString() => '$file: $message';
}
