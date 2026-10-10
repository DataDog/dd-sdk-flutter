// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:datadog_flags/datadog_flags.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

Future<void> main(List<String> arguments) async {
  final parser = _argumentParser();
  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }

  if (results.flag('help')) {
    stdout.writeln(parser.usage);
    return;
  }

  final attributes = _targetingAttributes(
    results.option('targeting-attributes'),
  );
  final flagKey = results.option('flag-key')!;
  final flagType = results.option('flag-type')!;
  final api = OpenFeatureAPI.instance;
  await api.setEvaluationContextAndWait(
    EvaluationContext(
      targetingKey: results.option('targeting-key'),
      attributes: attributes,
    ),
  );
  try {
    await api.setProviderAndWait(
      DatadogOpenFeatureProvider(
        configuration: DatadogFlagsConfiguration(
          datadogConfig: DatadogFlagsConfig(
            clientToken: Platform.environment['DD_CLIENT_TOKEN'] ?? '',
            env: results.option('env')!,
            site: _siteFromOption(results.option('site')!),
            applicationId: Platform.environment['DD_APPLICATION_ID'],
          ),
        ),
      ),
    );
  } on OpenFeatureException catch (error) {
    stderr.writeln(error.message);
  }
  final flags = api.getClient();

  final details = _evaluate(flags, flagKey, flagType);
  stdout.writeln('key: ${details.flagKey}');
  stdout.writeln('value: ${jsonEncode(details.value)}');
  stdout.writeln('variant: ${details.variant ?? '(none)'}');
  stdout.writeln('reason: ${details.reason ?? '(none)'}');
  stdout.writeln('error: ${details.errorCode?.name ?? '(none)'}');

  await api.shutdown();
}

ArgParser _argumentParser() {
  return ArgParser()
    ..addOption('env', defaultsTo: 'staging', help: 'Datadog environment name.')
    ..addOption(
      'site',
      defaultsTo: 'us1',
      allowed: DatadogFlagsSite.values.map((site) => site.name),
      help: 'Datadog site.',
    )
    ..addOption(
      'flag-key',
      defaultsTo: 'checkout.enabled',
      help: 'Feature flag key to evaluate.',
    )
    ..addOption(
      'flag-type',
      defaultsTo: 'boolean',
      allowed: ['boolean', 'string', 'integer', 'double', 'float', 'json'],
      help: 'Expected flag value type.',
    )
    ..addOption(
      'targeting-key',
      help: 'Optional targeting key for the evaluation subject.',
    )
    ..addOption(
      'targeting-attributes',
      help: 'Optional JSON object with targeting attributes.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Print usage.');
}

FlagEvaluationDetails<Object> _evaluate(
  OpenFeatureClient flags,
  String flagKey,
  String flagType,
) {
  return switch (flagType) {
    'boolean' => flags.getBooleanDetails(flagKey, false),
    'string' => flags.getStringDetails(flagKey, ''),
    'integer' => flags.getIntegerDetails(flagKey, 0),
    'double' || 'float' => flags.getDoubleDetails(flagKey, 0),
    'json' => flags.getStructureDetails(flagKey, const {}),
    _ => flags.getBooleanDetails(flagKey, false),
  };
}

Map<String, Object?> _targetingAttributes(String? json) {
  if (json == null || json.isEmpty) {
    return const {};
  }

  try {
    final decoded = jsonDecode(json);
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
  } catch (_) {
    return const {};
  }

  return const {};
}

DatadogFlagsSite _siteFromOption(String option) {
  return DatadogFlagsSite.values.firstWhere((site) => site.name == option);
}
