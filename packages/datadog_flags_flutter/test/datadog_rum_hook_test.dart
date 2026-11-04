// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk_experimental.dart';

class _Sdk extends Mock implements DatadogSdk {}

class _Rum extends Mock implements DatadogRum {}

void main() {
  for (final optedOut in [false, true]) {
    for (final type in ['boolean', 'string', 'integer', 'float', 'object']) {
      test('Datadog provider RUM hook: $type optedOut=$optedOut', () async {
        final sdk = _Sdk();
        final rum = _Rum();
        when(() => sdk.rum).thenReturn(rum);
        final api = createIsolatedOpenFeatureAPI();
        addTearDown(api.shutdown);
        final requested = Completer<void>();
        final responseReady = Completer<void>();
        var assignmentRequests = 0;
        final value = switch (type) {
          'boolean' => true,
          'string' => 'value',
          'integer' => 2,
          'float' => 2.5,
          _ => <String, Object?>{'enabled': true},
        };
        await api.setEvaluationContextAndWait(
          EvaluationContext(
            targetingKey: 'subject',
            attributes: {'dd_evaluation_telemetry_opt_out': optedOut},
          ),
        );
        await api.setProviderAndWait(
          DatadogOpenFeatureProvider(
            configuration: DatadogFlagsConfiguration(
              datadogConfig: const DatadogFlagsConfig(
                clientToken: 'local-test-token',
                env: 'test',
                site: DatadogFlagsSite.us1,
              ),
              enableEvaluationTelemetryOptOutParameter: true,
              httpClient: MockClient((request) async {
                if (request.url.path.contains('precompute') &&
                    ++assignmentRequests == 2) {
                  requested.complete();
                  await responseReady.future;
                }
                return http.Response(
                  request.url.path.contains('precompute')
                      ? jsonEncode({
                          'data': {
                            'attributes': {
                              'flags': {
                                'flag': {
                                  'allocationKey': 'allocation',
                                  'variationKey': 'variant',
                                  'variationType': type,
                                  'variationValue': value,
                                  'reason': 'TARGETING_MATCH',
                                  'doLog': false,
                                },
                              },
                            },
                          },
                        })
                      : '{}',
                  200,
                );
              }),
            ),
          ),
        );
        final client = api.getClient()..addHooks([DatadogRumHook(sdk: sdk)]);
        FlagEvaluationDetails<Object> evaluate() => switch (type) {
          'boolean' => client.getBooleanDetails('flag', false),
          'string' => client.getStringDetails('flag', ''),
          'integer' => client.getIntegerDetails('flag', 0),
          'float' => client.getDoubleDetails('flag', 0),
          _ => client.getStructureDetails('flag', <String, Object?>{}),
        };
        final details = evaluate();
        expect(details.errorCode, isNull);
        expect(details.value, value);
        expect(
          details.flagMetadata[DatadogOpenFeatureProvider
              .evaluationTelemetryOptOutMetadata],
          optedOut ? true : null,
        );
        if (optedOut) {
          verifyNever(() => rum.addFeatureFlagEvaluation(any(), any()));
        } else {
          verify(
            () => rum.addFeatureFlagEvaluation('flag', 'variant'),
          ).called(1);
        }
        final reconciliation = api.setEvaluationContextAndWait(
          EvaluationContext(
            targetingKey: 'next-subject',
            attributes: {'dd_evaluation_telemetry_opt_out': !optedOut},
          ),
        );
        await requested.future;
        final pendingDetails = evaluate();
        expect(
          pendingDetails.flagMetadata[DatadogOpenFeatureProvider
              .evaluationTelemetryOptOutMetadata],
          optedOut ? true : null,
        );
        if (optedOut) {
          verifyNever(() => rum.addFeatureFlagEvaluation(any(), any()));
        } else {
          verify(
            () => rum.addFeatureFlagEvaluation('flag', 'variant'),
          ).called(1);
        }
        responseReady.complete();
        await reconciliation;
        final nextDetails = evaluate();
        expect(
          nextDetails.flagMetadata[DatadogOpenFeatureProvider
              .evaluationTelemetryOptOutMetadata],
          optedOut ? null : true,
        );
        if (optedOut) {
          verify(
            () => rum.addFeatureFlagEvaluation('flag', 'variant'),
          ).called(1);
        } else {
          verifyNever(() => rum.addFeatureFlagEvaluation(any(), any()));
        }
      });
    }
  }

  test(
    'OpenFeature hook tags successful evaluations and skips errors',
    () async {
      final sdk = _Sdk();
      final rum = _Rum();
      when(() => sdk.rum).thenReturn(rum);
      final api = createIsolatedOpenFeatureAPI();
      addTearDown(api.shutdown);
      await api.setProviderAndWait(InMemoryProvider({'enabled': true}));
      final client = api.getClient();
      client.addHooks([DatadogRumHook(sdk: sdk)]);
      expect(client.getBooleanValue('enabled', false), isTrue);
      verify(() => rum.addFeatureFlagEvaluation('enabled', true)).called(1);
      client.getBooleanValue('missing', false);
      client.getStringValue('enabled', 'fallback');
      verifyNoMoreInteractions(rum);
    },
  );
}
