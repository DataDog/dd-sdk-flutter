// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

class _MockSdk extends Mock implements DatadogSdk {}

void main() {
  test(
      'event-only callback uses an externally captured existing Flutter client',
      () async {
    final sdk = _MockSdk();
    when(() => sdk.configuration).thenReturn(DatadogConfiguration(
        clientToken: 'client-token', env: 'test', site: DatadogSite.us1));
    final flags = DatadogFlags();
    late DatadogFlutterFlagsClient client;
    FlagDetails<bool>? early;
    FlagsClientEvent? firstEvent;
    var calls = 0;
    final plugin = DatadogFlagsPlugin(sdk,
        flags: flags,
        rumIntegrationEnabled: false,
        flagsConfiguration: DatadogFlagsConfiguration(
          onFirstFlags: (event) {
            calls++;
            firstEvent = event;
            early = client.getBooleanDetails(
                key: 'checkout.enabled', defaultValue: false);
          },
          httpClient: MockClient((_) async => http.Response(
              jsonEncode({
                'data': {
                  'attributes': {
                    'flags': {
                      'checkout.enabled': {
                        'allocationKey': 'allocation',
                        'variationKey': 'enabled',
                        'variationType': 'boolean',
                        'variationValue': true,
                        'reason': 'TARGETING_MATCH',
                        'doLog': true,
                      }
                    }
                  }
                }
              }),
              200)),
        ));
    addTearDown(flags.disable);
    plugin.initialize();
    await plugin.ready;
    // Application ownership: bind before starting the existing initialization.
    client = plugin.sharedClient();
    await client
        .initialize(const FlagsEvaluationContext(targetingKey: 'example-user'));
    expect(calls, 1);
    expect(firstEvent!.flagsChanged, ['checkout.enabled']);
    expect(early!.value, isTrue);
    expect(early!.variant, 'enabled');
    expect(early!.reason, 'TARGETING_MATCH');
    expect(early!.error, isNull);
    await client
        .initialize(const FlagsEvaluationContext(targetingKey: 'another-user'));
    expect(calls, 1);
  });
}
