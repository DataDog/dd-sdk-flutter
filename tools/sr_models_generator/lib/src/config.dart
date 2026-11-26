// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

import 'package:checked_yaml/checked_yaml.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:yaml_edit/yaml_edit.dart';

import 'resolver.dart';
import 'schema_source.dart';

part 'config.g.dart';

/// The generator configuration, read from `sr_models_generator.yaml`.
@immutable
@JsonSerializable(
  anyMap: true,
  checked: true,
  createToJson: false,
  disallowUnrecognizedKeys: true,
  fieldRename: FieldRename.snake,
)
final class GeneratorConfig {
  GeneratorConfig({
    required this.rumEventsFormat,
    required this.rootSchemas,
    required this.output,
    this.localSchemas,
    this.samples,
    this.typePrefix,
    this.stripFromTitles,
    this.typeRenames,
    this.file = '',
  }) {
    if (rootSchemas.isEmpty) {
      throw ArgumentError.value(
        rootSchemas,
        'rootSchemas',
        'Must not be empty.',
      );
    }
    for (final schema in rootSchemas) {
      schema.checkNotBlank('rootSchemas');
    }
    output.checkNotBlank('output');
    localSchemas?.checkNotBlank('localSchemas');
    typePrefix?.checkNotBlank('typePrefix');
    for (final prefix in stripFromTitles ?? const <String>[]) {
      prefix.checkNotBlank('stripFromTitles');
    }
    for (final MapEntry(:key, :value) in (typeRenames ?? const {}).entries) {
      key.checkNotBlank('typeRenames');
      value.checkNotBlank('typeRenames');
    }
  }

  factory GeneratorConfig.fromJson(Map json) => _$GeneratorConfigFromJson(json);

  /// Reads and validates the configuration file at [path].
  factory GeneratorConfig.load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw ConfigException('Configuration file not found: $path');
    }
    return GeneratorConfig.parse(file.readAsStringSync(), file: path);
  }

  /// Parses [source], the contents of the configuration file at [file].
  ///
  /// [output], [localSchemas] and the samples' output are resolved against
  /// the directory of [file].
  factory GeneratorConfig.parse(String source, {required String file}) {
    final GeneratorConfig config;
    try {
      config = checkedYamlDecode(
        source,
        (map) => GeneratorConfig.fromJson(map!),
        sourceUrl: Uri.file(file),
      );
    } on ParsedYamlException catch (e) {
      throw ConfigException(e.formattedMessage ?? e.message);
    }
    String resolve(String path) => p.normalize(p.join(p.dirname(file), path));
    final localSchemas = switch (config.localSchemas) {
      final path? => resolve(path),
      null => null,
    };
    if (localSchemas != null && !Directory(localSchemas).existsSync()) {
      throw ConfigException(
        '$file: "local_schemas" is not a directory: $localSchemas',
      );
    }
    return GeneratorConfig(
      file: file,
      rumEventsFormat: config.rumEventsFormat,
      rootSchemas: config.rootSchemas,
      output: resolve(config.output),
      localSchemas: localSchemas,
      samples: switch (config.samples) {
        final samples? => Samples(
          directory: samples.directory,
          output: resolve(samples.output),
        ),
        null => null,
      },
      typePrefix: config.typePrefix,
      stripFromTitles: config.stripFromTitles,
      typeRenames: config.typeRenames,
    );
  }

  /// The folder under which the schemas of [localSchemas] appear to the
  /// rum-events-format schemas.
  static const localSchemasFolder = 'flutter';

  /// The configuration file's path; not a setting.
  @JsonKey(includeFromJson: false)
  final String file;

  @JsonKey(required: true)
  final RumEventsFormat rumEventsFormat;

  /// Entry points of the schemas, relative to the rum-events-format root;
  /// the schemas of [localSchemas] are under [localSchemasFolder].
  @JsonKey(required: true)
  final List<String> rootSchemas;

  /// Resolved against the configuration file's directory.
  @JsonKey(required: true)
  final String output;

  /// Resolved against the configuration file's directory.
  final String? localSchemas;

  final Samples? samples;

  final String? typePrefix;

  final List<String>? stripFromTitles;

  /// Generated name or schema location -> the name to use.
  final Map<String, String>? typeRenames;

  String get repository => rumEventsFormat.repository;

  String get commit => rumEventsFormat.commit;

  /// The `mounts` of a `SchemaLoader` that makes [localSchemas] available.
  Map<String, String> get schemaMounts => {localSchemasFolder: ?localSchemas};

  /// How generated types are named.
  NamingOptions get naming => NamingOptions(
    typePrefix: typePrefix ?? const NamingOptions().typePrefix,
    stripFromTitles: stripFromTitles ?? const NamingOptions().stripFromTitles,
    renames: typeRenames ?? const NamingOptions().renames,
  );

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
    final updated = (YamlEditor(
      source,
    )..update(['rum_events_format', 'commit'], sha)).toString();
    // Parsed again, so that an invalid SHA fails like in the file.
    GeneratorConfig.parse(updated, file: file);
    return updated;
  }
}

/// The `rum_events_format` section: where the schemas come from.
@immutable
@JsonSerializable(
  anyMap: true,
  checked: true,
  createToJson: false,
  disallowUnrecognizedKeys: true,
)
final class RumEventsFormat {
  RumEventsFormat({required this.repository, required this.commit}) {
    repository.checkNotBlank('repository');
    // The pin must be an exact commit, not a branch or tag that can move.
    if (!isFullCommitSha(commit)) {
      throw ArgumentError.value(
        commit,
        'commit',
        'Must be a full 40-character commit SHA.',
      );
    }
  }

  factory RumEventsFormat.fromJson(Map json) => _$RumEventsFormatFromJson(json);

  /// Git URL of rum-events-format.
  @JsonKey(required: true)
  final String repository;

  /// Full SHA of the pinned commit.
  @JsonKey(required: true)
  final String commit;
}

/// The `samples` section: the rum-events-format samples written as Dart
/// constants, for the tests of the generated models.
@immutable
@JsonSerializable(
  anyMap: true,
  checked: true,
  createToJson: false,
  disallowUnrecognizedKeys: true,
)
final class Samples {
  Samples({required this.directory, required this.output}) {
    directory.checkNotBlank('directory');
    output.checkNotBlank('output');
  }

  factory Samples.fromJson(Map json) => _$SamplesFromJson(json);

  /// The folder of the samples, relative to the rum-events-format root.
  @JsonKey(required: true)
  final String directory;

  /// Resolved against the configuration file's directory.
  @JsonKey(required: true)
  final String output;
}

extension on String {
  void checkNotBlank(String name) {
    if (trim().isEmpty) {
      throw ArgumentError.value(this, name, 'Must not be blank.');
    }
  }
}

/// The configuration file is missing or invalid.
@immutable
final class ConfigException implements Exception {
  ConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}
