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

void main() {
  test('evaluates encoded assignments and reports the original key to RUM',
      () async {
    final sdk = DatadogFlags();
    final requests = <http.Request>[];
    await sdk.enable(
        configuration: DatadogFlagsConfiguration(
      datadogConfig: const DatadogFlagsConfig(
        clientToken: 'test-token',
        env: 'test',
        site: DatadogFlagsSite.us1,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
            jsonEncode({
              'data': {
                'attributes': {
                  'obfuscated': true,
                  'obfuscation': {
                    'scheme': 'flag-key-sha256-v1',
                    'salt': '000102030405060708090a0b0c0d0e0f'
                  },
                  'flags': {
                    '9817872c144b018abd77e3915bd77e2c27f4f534dccff8ffaca27361e3a5e1ee':
                        {
                      'allocationKey': 'allocation',
                      'variationKey': 'variant',
                      'variationType': 'boolean',
                      'variationValue': true,
                      'reason': 'TARGETING_MATCH',
                      'doLog': false,
                    }
                  },
                }
              },
            }),
            200);
      }),
      trackEvaluations: false,
    ));
    addTearDown(sdk.disable);
    final rum = <MapEntry<String, Object>>[];
    final client = DatadogFlutterFlagsClient(
      name: 'default',
      resolveDelegate: () async => sdk.sharedClient(),
      addRumFeatureFlagEvaluation: (key, value) =>
          rum.add(MapEntry(key, value)),
    );
    await client
        .initialize(const FlagsEvaluationContext(targetingKey: 'subject'));
    final details = client.getBooleanDetails(key: 'flag', defaultValue: false);
    expect(details.value, isTrue);
    expect(details.key, 'flag');
    expect(rum.single.key, 'flag');
    expect(rum.single.value, 'variant');
    final attributes = jsonDecode(requests.single.body)['data']['attributes'];
    expect(attributes['source']['sdk_name'], 'dd-sdk-dart');
    expect(attributes.containsKey('supported_capabilities'), isFalse);
    expect(requests.single.headers['X-DD-FEATURE-FLAGS-CAPABILITIES'],
        'assignment-encoding-flag-key-256-v1');
  });
}
