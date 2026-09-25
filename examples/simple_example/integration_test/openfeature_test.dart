// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';
import 'package:test_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('example evaluates, refreshes, changes identity and shuts down', (
    tester,
  ) async {
    final requests = <http.Request>[];
    var enabled = true;
    final transport = MockClient((request) async {
      requests.add(request);
      if (request.url.path != '/precompute-assignments') {
        return http.Response('{}', 202);
      }
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
    dotenv.testLoad(
      fileInput: '''
DD_CLIENT_TOKEN=simulator-test-token
DD_APPLICATION_ID=00000000-0000-0000-0000-000000000001
DD_ENV=integration-test
DD_SITE=us1
FLAGS_TARGETING_KEY=simulator-user
''',
    );
    await app.startExample(
      flagsHttpClient: transport,
      consent: TrackingConsent.notGranted,
      loadEnvironment: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flags'));
    await tester.pumpAndSettle();
    expect(find.text('OpenFeature on device'), findsOneWidget);
    final client = api.getClient();
    expect(client.providerStatus, ProviderStatus.ready);
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
    final refreshButton = find.widgetWithText(
      ElevatedButton,
      'Refresh assignments',
    );
    await tester.ensureVisible(refreshButton);
    await tester.tap(refreshButton);
    await tester.pumpAndSettle();
    expect(client.getBooleanValue('checkout.enabled', true), isFalse);
    await api.setEvaluationContextAndWait(
      EvaluationContext(targetingKey: 'second-user'),
    );
    await tester.pumpAndSettle();
    expect(client.getStringValue('checkout.copy', ''), 'second-user');
    expect(
      requests.where((r) => r.url.path == '/precompute-assignments'),
      hasLength(3),
    );
    await api.shutdown();
    expect(client.providerStatus, ProviderStatus.notReady);
    expect(client.getBooleanValue('checkout.enabled', true), isTrue);
    expect(requests.any((r) => r.url.path == '/api/v2/exposures'), isTrue);
    expect(requests.any((r) => r.url.path == '/api/v2/flagevaluation'), isTrue);
  });
}
