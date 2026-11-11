// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// The integration matrix covers the supported legacy client API.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flags/datadog_flags.dart' show DatadogFlags;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'OpenFeature evaluates, refreshes, changes identity and shuts down',
    (tester) async {
      final requests = <http.Request>[];
      var enabled = true;
      Completer<void>? assignmentGate;
      final transport = MockClient((request) async {
        requests.add(request);
        if (request.url.path != '/precompute-assignments') {
          return http.Response('{}', 202);
        }
        await assignmentGate?.future;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final subject = body['data']['attributes']['subject']['targeting_key'];
        final values = <String, Object>{
          'checkout.enabled': enabled,
          'checkout.copy': subject == 'second-user'
              ? 'second-user'
              : 'OpenFeature on device',
          'checkout.limit': 7,
          'checkout.ratio': 0.5,
          'checkout.config': <String, Object>{'layout': 'compact'},
        };
        return http.Response(
          jsonEncode({
            'data': {
              'attributes': {
                'flags': {
                  for (final entry in values.entries)
                    entry.key: {
                      'allocationKey': 'simulator-allocation',
                      'variationKey': 'test-variant',
                      'variationType': switch (entry.value) {
                        bool() => 'boolean',
                        int() => 'integer',
                        double() => 'float',
                        String() => 'string',
                        _ => 'object',
                      },
                      'variationValue': entry.value,
                      'reason': 'TARGETING_MATCH',
                      'doLog': true,
                    },
                },
              },
            },
          }),
          200,
        );
      });
      addTearDown(transport.close);
      final api = OpenFeatureAPI.instance;
      addTearDown(api.shutdown);
      await DatadogSdk.instance.initialize(
        DatadogConfiguration(
          service: 'openfeature.integration',
          clientToken: 'simulator-test-token',
          env: 'integration-test',
          site: DatadogSite.us1,
        ),
        TrackingConsent.notGranted,
      );
      await api.setEvaluationContextAndWait(
        EvaluationContext(
          targetingKey: 'simulator-user',
          attributes: {'signupDate': DateTime.utc(2026, 1, 2)},
        ),
      );
      final provider = DatadogProvider(
        clientToken: 'simulator-test-token',
        env: 'integration-test',
        site: DatadogFlagsSite.us1,
        httpClient: transport,
      );
      api.addHooks([DatadogRumHook()]);
      await api.setProviderAndWait(provider);
      await tester.pumpWidget(
        const MaterialApp(home: Text('OpenFeature test')),
      );
      final client = api.getClient();
      expect(client.providerStatus, ProviderStatus.ready);
      expect(
        client.getStringValue('checkout.copy', ''),
        'OpenFeature on device',
      );
      expect(client.getBooleanValue('checkout.enabled', false), isTrue);
      expect(client.getIntegerValue('checkout.limit', 0), 7);
      expect(client.getDoubleValue('checkout.ratio', 0), 0.5);
      expect(client.getStructureValue('checkout.config', {}), {
        'layout': 'compact',
      });
      expect(
        client.getStringDetails('missing', 'default').errorCode,
        ErrorCode.flagNotFound,
      );
      enabled = false;
      await provider.refresh();
      await tester.pumpAndSettle();
      expect(client.getBooleanValue('checkout.enabled', true), isFalse);
      assignmentGate = Completer<void>();
      final changingIdentity = api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'second-user'),
      );
      await tester.pump();
      expect(
        client.getStringDetails('checkout.copy', 'default').errorCode,
        ErrorCode.providerNotReady,
      );
      assignmentGate.complete();
      await changingIdentity;
      assignmentGate = null;
      await tester.pumpAndSettle();
      expect(client.getStringValue('checkout.copy', ''), 'second-user');
      expect(
        requests.where((r) => r.url.path == '/precompute-assignments'),
        hasLength(3),
      );
      final initialBody =
          jsonDecode(
                requests
                    .firstWhere((r) => r.url.path == '/precompute-assignments')
                    .body,
              )
              as Map<String, dynamic>;
      expect(
        initialBody['data']['attributes']['subject']['targeting_attributes']['signupDate'],
        '2026-01-02T00:00:00.000Z',
      );
      await api.shutdown();
      expect(client.providerStatus, ProviderStatus.notReady);
      expect(client.getBooleanValue('checkout.enabled', true), isTrue);
      expect(requests.any((r) => r.url.path == '/api/v2/exposures'), isTrue);
      expect(
        requests.any((r) => r.url.path == '/api/v2/flagevaluation'),
        isTrue,
      );
    },
  );
  for (final direct in [false, true]) {
    for (final strict in [false, true]) {
      testWidgets(
        '${direct ? 'Dart' : 'OpenFeature'} context policy strict=$strict',
        (tester) async {
          final requests = <http.Request>[];
          Completer<http.Response>? response;
          Completer<void>? started;
          final transport = MockClient((request) async {
            requests.add(request);
            if (request.url.path != '/precompute-assignments') {
              return http.Response('{}', 202);
            }
            if (response != null) {
              final gate = started;
              if (gate != null && !gate.isCompleted) gate.complete();
              return response.future;
            }
            final subject =
                (jsonDecode(request.body)
                    as Map<String, dynamic>)['data']['attributes']['subject'];
            return http.Response(
              jsonEncode({
                'data': {
                  'attributes': {
                    'flags': {
                      'identity': {
                        'allocationKey': 'integration',
                        'variationKey': 'subject',
                        'variationType': 'string',
                        'variationValue': subject['targeting_key'],
                        'reason': 'TARGETING_MATCH',
                        'doLog': true,
                      },
                    },
                  },
                },
              }),
              200,
            );
          });
          addTearDown(transport.close);
          final api = OpenFeatureAPI.instance;
          addTearDown(api.shutdown);
          final owner = DatadogFlags();
          addTearDown(owner.disable);
          final configuration = DatadogFlagsConfiguration(
            datadogConfig: const DatadogFlagsConfig(
              clientToken: 'synthetic',
              env: 'test',
              site: DatadogFlagsSite.us1,
            ),
            httpClient: transport,
          );
          late Future<void> Function(String, String) change;
          late String Function() read;
          final policy = {'dd_strict_evaluation_context_switching': strict};
          if (direct) {
            await owner.enable(configuration: configuration);
            final client = owner.sharedClient();
            change = (key, plan) => client.initialize(
              FlagsEvaluationContext(
                targetingKey: key,
                attributes: {...policy, 'plan': plan},
              ),
            );
            read = () => client
                .getStringDetails(key: 'identity', defaultValue: 'default')
                .value;
            await change('A', 'free');
          } else {
            change = (key, plan) => api.setEvaluationContextAndWait(
              EvaluationContext(
                targetingKey: key,
                attributes: {...policy, 'plan': plan},
              ),
            );
            await change('A', 'free');
            await api.setProviderAndWait(
              DatadogProvider.fromConfiguration(configuration),
            );
            read = () => api.getClient().getStringValue('identity', 'default');
          }
          expect(read(), 'A');
          for (final key in ['A', 'B', '']) {
            response = Completer<http.Response>();
            started = Completer<void>();
            final operation = change(key, 'pro');
            final completion = direct
                ? operation
                : expectLater(operation, throwsA(isA<OpenFeatureException>()));
            await started.future;
            expect(read(), !strict && key == 'A' ? 'A' : 'default');
            response.complete(http.Response('offline', 503));
            await completion;
            expect(read(), !strict && key == 'A' ? 'A' : 'default');
          }
          response = null;
          await change('C', 'pro');
          expect(read(), 'C');
          await api.shutdown();
          await owner.disable();
          for (final request in requests) {
            expect(
              request.body,
              isNot(contains('dd_strict_evaluation_context_switching')),
            );
          }
          final exposures = requests
              .where((request) => request.url.path == '/api/v2/exposures')
              .expand((request) => const LineSplitter().convert(request.body))
              .map((line) => jsonDecode(line) as Map<String, dynamic>)
              .toList();
          expect(exposures, isNotEmpty);
          expect(exposures.last['subject'], {
            'id': 'C',
            'attributes': {'plan': 'pro'},
          });
          expect(exposures.first['subject'], {
            'id': 'A',
            'attributes': {'plan': 'free'},
          });
        },
      );
    }
  }
}
