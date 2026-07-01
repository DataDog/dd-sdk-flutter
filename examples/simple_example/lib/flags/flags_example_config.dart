// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final class FlagsExampleConfig {
  final DatadogFlagsConfiguration configuration;
  final FlagsEvaluationContext evaluationContext;
  final List<FlagsExampleFlag> flags;

  const FlagsExampleConfig._({
    required this.configuration,
    required this.evaluationContext,
    required this.flags,
  });

  factory FlagsExampleConfig.fromDotEnv({
    required String clientToken,
    required String env,
    required String? siteName,
    required String? applicationId,
  }) {
    final datadogConfig = _datadogConfig(
      clientToken: clientToken,
      env: env,
      siteName: siteName,
      applicationId: applicationId,
    );

    return FlagsExampleConfig._(
      configuration: DatadogFlagsConfiguration(datadogConfig: datadogConfig),
      evaluationContext: FlagsEvaluationContext(
        targetingKey:
            dotenv.get('FLAGS_TARGETING_KEY', fallback: 'test_subject4'),
        attributes: _attributesFromJson(
          dotenv.get(
            'FLAGS_TARGETING_ATTRIBUTES_JSON',
            fallback: '{"attr1":"value1","companyId":"1"}',
          ),
        ),
      ),
      flags: [
        ..._flagSpecs(
          dotenv.maybeGet('FLAGS_BOOLEAN_KEYS'),
          const ['checkout.enabled'],
          'Boolean',
          FlagsExampleFlagType.boolean,
        ),
        ..._flagSpecs(
          dotenv.maybeGet('FLAGS_STRING_KEYS'),
          const ['checkout.copy'],
          'String',
          FlagsExampleFlagType.string,
        ),
        ..._flagSpecs(
          dotenv.maybeGet('FLAGS_INTEGER_KEYS'),
          const ['checkout.limit'],
          'Integer',
          FlagsExampleFlagType.integer,
        ),
        ..._flagSpecs(
          dotenv.maybeGet('FLAGS_DOUBLE_KEYS'),
          const ['checkout.ratio'],
          'Float',
          FlagsExampleFlagType.float,
        ),
        ..._flagSpecs(
          dotenv.maybeGet('FLAGS_OBJECT_KEYS'),
          const ['checkout.config'],
          'JSON',
          FlagsExampleFlagType.object,
        ),
      ],
    );
  }
}

final class FlagsExampleFlag {
  final String label;
  final String key;
  final FlagsExampleFlagType type;

  const FlagsExampleFlag({
    required this.label,
    required this.key,
    required this.type,
  });
}

enum FlagsExampleFlagType { boolean, string, integer, float, object }

DatadogFlagsConfig? _datadogConfig({
  required String clientToken,
  required String env,
  required String? siteName,
  required String? applicationId,
}) {
  if (clientToken.isEmpty) {
    return null;
  }

  return DatadogFlagsConfig(
    clientToken: clientToken,
    env: env.isEmpty ? 'dev' : env,
    site: _flagsSiteForName(siteName),
    service: 'simple-example',
    version: '1.0.0',
    applicationId: _emptyToNull(applicationId),
  );
}

DatadogFlagsSite _flagsSiteForName(String? siteName) {
  return switch (siteName) {
    'datad0g.com' => DatadogFlagsSite.us1Staging,
    'us3' || 'us3.datadoghq.com' => DatadogFlagsSite.us3,
    'us5' || 'us5.datadoghq.com' => DatadogFlagsSite.us5,
    'eu1' || 'datadoghq.eu' => DatadogFlagsSite.eu1,
    'ap1' || 'ap1.datadoghq.com' => DatadogFlagsSite.ap1,
    'ap2' || 'ap2.datadoghq.com' => DatadogFlagsSite.ap2,
    _ => DatadogFlagsSite.us1,
  };
}

List<FlagsExampleFlag> _flagSpecs(
  String? configured,
  List<String> defaultKeys,
  String label,
  FlagsExampleFlagType type,
) {
  final keys = _keys(configured, defaultKeys);
  return [
    for (final key in keys)
      FlagsExampleFlag(label: label, key: key, type: type),
  ];
}

List<String> _keys(String? configured, List<String> defaultKeys) {
  final value = configured?.trim();
  if (value == null || value.isEmpty) {
    return defaultKeys;
  }
  return value
      .split(',')
      .map((key) => key.trim())
      .where((key) => key.isNotEmpty)
      .toList(growable: false);
}

Map<String, Object?> _attributesFromJson(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
  } catch (_) {
    return const {};
  }
  return const {};
}

String? _emptyToNull(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}
