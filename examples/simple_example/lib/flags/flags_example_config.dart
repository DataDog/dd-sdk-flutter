// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const _stagingRumEndpoint = 'https://browser-intake-datad0g.com/api/v2/rum';
const _stagingLogsEndpoint = 'https://browser-intake-datad0g.com/api/v2/logs';
const _datadogSiteAliases = {
  'datadoghq.com': DatadogSite.us1,
  'app.datadoghq.com': DatadogSite.us1,
  'us3.datadoghq.com': DatadogSite.us3,
  'us5.datadoghq.com': DatadogSite.us5,
  'datadoghq.eu': DatadogSite.eu1,
  'app.datadoghq.eu': DatadogSite.eu1,
  'ddog-gov.com': DatadogSite.us1Fed,
  'ap1.datadoghq.com': DatadogSite.ap1,
  'ap2.datadoghq.com': DatadogSite.ap2,
};

final class FlagsExampleSiteConfig {
  final DatadogSite datadogSite;
  final DatadogFlagsSite flagsSite;
  final String? rumCustomEndpoint;
  final String? logsCustomEndpoint;
  final bool sessionReplayEnabled;

  const FlagsExampleSiteConfig._({
    required this.datadogSite,
    required this.flagsSite,
    this.sessionReplayEnabled = true,
    this.rumCustomEndpoint,
    this.logsCustomEndpoint,
  });

  factory FlagsExampleSiteConfig.fromName(String? siteName) {
    final normalizedSiteName = siteName?.trim();
    if (normalizedSiteName == 'datad0g.com') {
      return const FlagsExampleSiteConfig._(
        datadogSite: DatadogSite.us1,
        flagsSite: DatadogFlagsSite.us1Staging,
        rumCustomEndpoint: _stagingRumEndpoint,
        logsCustomEndpoint: _stagingLogsEndpoint,
        sessionReplayEnabled: false,
      );
    }

    final datadogSite = _datadogSiteForName(normalizedSiteName);
    return FlagsExampleSiteConfig._(
      datadogSite: datadogSite,
      flagsSite: datadogFlagsSiteFor(datadogSite) ?? DatadogFlagsSite.us1,
    );
  }
}

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
    required DatadogFlagsSite site,
    required String? applicationId,
  }) {
    final datadogConfig = _datadogConfig(
      clientToken: clientToken,
      env: env,
      site: site,
      applicationId: applicationId,
    );

    return FlagsExampleConfig._(
      configuration: DatadogFlagsConfiguration(datadogConfig: datadogConfig),
      evaluationContext: FlagsEvaluationContext(
        targetingKey: dotenv.get(
          'FLAGS_TARGETING_KEY',
          fallback: 'test_subject4',
        ),
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
  required DatadogFlagsSite site,
  required String? applicationId,
}) {
  if (clientToken.isEmpty) {
    return null;
  }

  return DatadogFlagsConfig(
    clientToken: clientToken,
    env: env.isEmpty ? 'dev' : env,
    site: site,
    service: 'simple-example',
    version: '1.0.0',
    applicationId: _emptyToNull(applicationId),
  );
}

DatadogSite _datadogSiteForName(String? siteName) {
  final normalizedSiteName = siteName?.trim();
  if (normalizedSiteName == null || normalizedSiteName.isEmpty) {
    return DatadogSite.us1;
  }
  final aliasedSite = _datadogSiteAliases[normalizedSiteName];
  if (aliasedSite != null) {
    return aliasedSite;
  }
  try {
    return DatadogSite.values.byName(normalizedSiteName);
  } on ArgumentError {
    return DatadogSite.us1;
  }
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
