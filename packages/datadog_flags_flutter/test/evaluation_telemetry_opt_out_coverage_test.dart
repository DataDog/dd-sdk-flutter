// Legacy API compatibility coverage.
// ignore_for_file: deprecated_member_use

// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements DatadogFlagsClient {}

const _key = 'dd_evaluation_telemetry_opt_out';

void main() {
  setUpAll(() => registerFallbackValue(FlagsEvaluationContext.empty));

  // Only the exact key with boolean true opts out.
  for (final attributes in <Map<String, Object?>>[
    {'DD_EVALUATION_TELEMETRY_OPT_OUT': true},
    {_key: '1'},
    {_key: 'yes'},
    {_key: 'TRUE'},
  ]) {
    test(
      'RUM is annotated unless exact key is boolean true: $attributes',
      () async {
        final sdk = DatadogFlags();
        addTearDown(sdk.disable);
        var evaluationCount = 0;
        await sdk.enable(
          configuration: DatadogFlagsConfiguration(
            datadogConfig: const DatadogFlagsConfig(
              clientToken: 'local-token',
              env: 'test',
              site: DatadogFlagsSite.us1,
            ),
            enableEvaluationTelemetryOptOutParameter: true,
            httpClient: MockClient((request) async {
              if (!request.url.path.contains('precompute')) {
                if (request.url.path.contains('evaluation')) {
                  for (final line in request.body.split('\n')) {
                    final decoded = jsonDecode(line);
                    final evaluations = decoded.containsKey('flagEvaluations')
                        ? decoded['flagEvaluations'] as List
                        : [decoded];
                    for (final evaluation in evaluations) {
                      evaluationCount += evaluation['evaluation_count'] as int;
                    }
                  }
                }
                return http.Response('{}', 202);
              }
              return http.Response(
                jsonEncode({
                  'data': {
                    'attributes': {
                      'flags': {
                        'flag': {
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
                200,
              );
            }),
          ),
        );
        final rum = <Object>[];
        final client = DatadogFlutterFlagsClient(
          name: 'default',
          resolveDelegate: () async => sdk.sharedClient(),
          enableEvaluationTelemetryOptOutParameter: true,
          addRumFeatureFlagEvaluation: (key, value) => rum.add(value),
        );
        await client.initialize(
          FlagsEvaluationContext(targetingKey: 'user', attributes: attributes),
        );
        client.getBooleanDetails(key: 'flag', defaultValue: false);
        await sdk.disable();
        expect(rum, ['on']);
        expect(evaluationCount, 1);
      },
    );
  }

  test('wrapper reset() clears the RUM policy', () async {
    final delegate = _MockClient();
    when(() => delegate.initialize(any())).thenAnswer((_) async {});
    when(() => delegate.reset()).thenAnswer((_) async {});
    when(
      () => delegate.getBooleanDetails(key: 'flag', defaultValue: false),
    ).thenReturn(const FlagDetails(key: 'flag', value: true, variant: 'on'));
    final rum = <Object>[];
    final client = DatadogFlutterFlagsClient(
      name: 'default',
      resolveDelegate: () async => delegate,
      enableEvaluationTelemetryOptOutParameter: true,
      addRumFeatureFlagEvaluation: (key, value) => rum.add(value),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'u', attributes: {_key: true}),
    );
    client.getBooleanDetails(key: 'flag', defaultValue: false);
    expect(rum, isEmpty);
    await client.reset();
    client.getBooleanDetails(key: 'flag', defaultValue: false);
    expect(rum, ['on']);
    verify(() => delegate.reset()).called(1);
  });

  for (final optedOut in [false, true]) {
    test(
      'all typed getters honour the RUM policy: optedOut=$optedOut',
      () async {
        final delegate = _MockClient();
        when(() => delegate.initialize(any())).thenAnswer((_) async {});
        when(
          () => delegate.getBooleanDetails(key: 'b', defaultValue: false),
        ).thenReturn(const FlagDetails(key: 'b', value: true, variant: 'vb'));
        when(
          () => delegate.getStringDetails(key: 's', defaultValue: ''),
        ).thenReturn(const FlagDetails(key: 's', value: 'x', variant: 'vs'));
        when(
          () => delegate.getIntegerDetails(key: 'i', defaultValue: 0),
        ).thenReturn(const FlagDetails(key: 'i', value: 1, variant: 'vi'));
        when(
          () => delegate.getDoubleDetails(key: 'd', defaultValue: 0),
        ).thenReturn(const FlagDetails(key: 'd', value: 1.5, variant: 'vd'));
        when(
          () => delegate.getObjectDetails(key: 'o', defaultValue: null),
        ).thenReturn(const FlagDetails(key: 'o', value: {}, variant: 'vo'));
        final rum = <Object>[];
        final client = DatadogFlutterFlagsClient(
          name: 'default',
          resolveDelegate: () async => delegate,
          enableEvaluationTelemetryOptOutParameter: true,
          addRumFeatureFlagEvaluation: (key, value) => rum.add(value),
        );
        await client.initialize(
          FlagsEvaluationContext(
            targetingKey: 'u',
            attributes: {_key: optedOut},
          ),
        );
        client.getBooleanDetails(key: 'b', defaultValue: false);
        client.getStringDetails(key: 's', defaultValue: '');
        client.getIntegerDetails(key: 'i', defaultValue: 0);
        client.getDoubleDetails(key: 'd', defaultValue: 0);
        client.getObjectDetails(key: 'o', defaultValue: null);
        expect(rum, optedOut ? isEmpty : ['vb', 'vs', 'vi', 'vd', 'vo']);
      },
    );
  }
}
