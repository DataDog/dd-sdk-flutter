// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeneratorConfig _$GeneratorConfigFromJson(Map json) => $checkedCreate(
  'GeneratorConfig',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'rum_events_format',
        'root_schemas',
        'output',
        'local_schemas',
        'samples',
        'type_prefix',
        'strip_from_titles',
        'type_renames',
      ],
      requiredKeys: const ['rum_events_format', 'root_schemas', 'output'],
    );
    final val = GeneratorConfig(
      rumEventsFormat: $checkedConvert(
        'rum_events_format',
        (v) => RumEventsFormat.fromJson(v as Map),
      ),
      rootSchemas: $checkedConvert(
        'root_schemas',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      output: $checkedConvert('output', (v) => v as String),
      localSchemas: $checkedConvert('local_schemas', (v) => v as String?),
      samples: $checkedConvert(
        'samples',
        (v) => v == null ? null : Samples.fromJson(v as Map),
      ),
      typePrefix: $checkedConvert('type_prefix', (v) => v as String?),
      stripFromTitles: $checkedConvert(
        'strip_from_titles',
        (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
      ),
      typeRenames: $checkedConvert(
        'type_renames',
        (v) => (v as Map?)?.map((k, e) => MapEntry(k as String, e as String)),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'rumEventsFormat': 'rum_events_format',
    'rootSchemas': 'root_schemas',
    'localSchemas': 'local_schemas',
    'typePrefix': 'type_prefix',
    'stripFromTitles': 'strip_from_titles',
    'typeRenames': 'type_renames',
  },
);

RumEventsFormat _$RumEventsFormatFromJson(Map json) =>
    $checkedCreate('RumEventsFormat', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['repository', 'commit'],
        requiredKeys: const ['repository', 'commit'],
      );
      final val = RumEventsFormat(
        repository: $checkedConvert('repository', (v) => v as String),
        commit: $checkedConvert('commit', (v) => v as String),
      );
      return val;
    });

Samples _$SamplesFromJson(Map json) =>
    $checkedCreate('Samples', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['directory', 'output'],
        requiredKeys: const ['directory', 'output'],
      );
      final val = Samples(
        directory: $checkedConvert('directory', (v) => v as String),
        output: $checkedConvert('output', (v) => v as String),
      );
      return val;
    });
