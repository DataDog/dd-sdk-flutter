// Legacy API compatibility coverage.
// ignore_for_file: deprecated_member_use

// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/flags_store.dart'
    show InMemoryDatadogFlagsStore;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _key = 'dd_evaluation_telemetry_opt_out';

void main() {
  // Only the exact key with boolean true opts out.
  for (final attributes in <Map<String, Object?>>[
    {'DD_EVALUATION_TELEMETRY_OPT_OUT': true},
    {'Dd_Evaluation_Telemetry_Opt_Out': true},
    {_key: '1'},
    {_key: 'yes'},
    {_key: 'TRUE'},
    {_key: 'on'},
    {_key: 1.0},
    {
      _key: [true],
    },
  ]) {
    test('only exact key with boolean true suppresses: $attributes', () async {
      final intake = _Intake();
      final sdk = DatadogFlags();
      addTearDown(sdk.disable);
      await sdk.enable(configuration: intake.configuration(enabled: true));
      final client = sdk.sharedClient();
      await client.initialize(
        FlagsEvaluationContext(targetingKey: 'user', attributes: attributes),
      );
      expect(
        client.getBooleanDetails(key: 'enabled', defaultValue: false).value,
        isTrue,
      );
      await sdk.disable();
      expect(intake.evaluationCount, 1);
      expect(intake.exposures, hasLength(1));
    });
  }

  test('client reset clears the opt-out policy', () async {
    final intake = _Intake();
    final store = InMemoryDatadogFlagsStore();
    final sdk = DatadogFlags();
    addTearDown(sdk.disable);
    await sdk.enable(
      configuration: intake.configuration(enabled: true, store: store),
    );
    final client = sdk.sharedClient();
    await client.initialize(
      const FlagsEvaluationContext(
        targetingKey: 'user',
        attributes: {_key: true},
      ),
    );
    client.getBooleanDetails(key: 'enabled', defaultValue: false);
    await client.reset();
    expect(
      client.getBooleanDetails(key: 'enabled', defaultValue: false).error,
      FlagEvaluationError.providerNotReady,
    );
    await sdk.disable();
    expect(intake.evaluationCount, 1);
    expect(intake.evaluations.single['error'], {
      'message': 'PROVIDER_NOT_READY',
    });
    expect(await store.read('default'), isNull);
  });

  test('client reset clears the opt-out for a subject without a key', () async {
    final intake = _Intake();
    final sdk = DatadogFlags();
    addTearDown(sdk.disable);
    await sdk.enable(configuration: intake.configuration(enabled: true));
    final client = sdk.sharedClient();
    await client.initialize(
      const FlagsEvaluationContext(attributes: {_key: true}),
    );
    client.getBooleanDetails(key: 'enabled', defaultValue: false);
    await client.reset();
    client.getBooleanDetails(key: 'enabled', defaultValue: false);
    await sdk.disable();
    expect(intake.evaluationCount, 1);
  });

  for (final site in ['providerNotReady', 'flagNotFound', 'typeMismatch']) {
    test('opt-out suppresses $site in isolation', () async {
      final intake = _Intake()
        ..assignmentStatus = site == 'providerNotReady' ? 400 : 200;
      final sdk = DatadogFlags();
      addTearDown(sdk.disable);
      await sdk.enable(configuration: intake.configuration(enabled: true));
      final client = sdk.sharedClient();
      await client.initialize(
        const FlagsEvaluationContext(
          targetingKey: 'user',
          attributes: {_key: true},
        ),
      );
      final details = switch (site) {
        'providerNotReady' => client.getBooleanDetails(
          key: 'enabled',
          defaultValue: false,
        ),
        'flagNotFound' => client.getBooleanDetails(
          key: 'missing',
          defaultValue: false,
        ),
        _ => client.getStringDetails(key: 'enabled', defaultValue: 'x'),
      };
      expect(details.evaluationTelemetryOptedOut, isTrue);
      expect(details.error?.code, switch (site) {
        'providerNotReady' => 'PROVIDER_NOT_READY',
        'flagNotFound' => 'FLAG_NOT_FOUND',
        _ => 'TYPE_MISMATCH',
      });
      await sdk.disable();
      expect(intake.evaluationCount, 0);
    });
  }
}

class _Intake {
  late final http.Client client = MockClient(_handle);
  final evaluations = <dynamic>[];
  final exposures = <dynamic>[];
  int assignmentStatus = 200;

  int get evaluationCount => evaluations.fold<int>(
    0,
    (count, event) => count + (event['evaluation_count'] as int),
  );

  DatadogFlagsConfiguration configuration({
    bool enabled = false,
    DatadogFlagsStore? store,
  }) => DatadogFlagsConfiguration(
    datadogConfig: const DatadogFlagsConfig(
      clientToken: 'local-test-token',
      env: 'local-test',
      site: DatadogFlagsSite.us1,
    ),
    customFlagsEndpoint: Uri.parse('https://flags.test/assignments'),
    customExposureEndpoint: Uri.parse('https://flags.test/exposures'),
    customEvaluationEndpoint: Uri.parse('https://flags.test/evaluations'),
    enableEvaluationTelemetryOptOutParameter: enabled,
    store: store,
    httpClient: client,
  );

  Future<http.Response> _handle(http.Request request) async {
    final body = request.body;
    if (request.url.path == '/assignments') {
      return http.Response(
        jsonEncode({
          'data': {
            'attributes': {
              'flags': {
                'enabled': {
                  'allocationKey': 'allocation',
                  'variationKey': 'on',
                  'variationType': 'boolean',
                  'variationValue': true,
                  'reason': 'TARGETING_MATCH',
                  'doLog': true,
                },
              },
            },
          },
        }),
        assignmentStatus,
        headers: {'content-type': 'application/json'},
      );
    } else if (request.url.path == '/evaluations') {
      for (final line in body.split('\n').where((line) => line.isNotEmpty)) {
        final decoded = jsonDecode(line);
        evaluations.addAll(
          decoded.containsKey('flagEvaluations')
              ? decoded['flagEvaluations'] as List
              : [decoded],
        );
      }
    } else if (request.url.path == '/exposures') {
      exposures.addAll(body.split('\n').map(jsonDecode));
    }
    return http.Response('{}', 202);
  }
}
