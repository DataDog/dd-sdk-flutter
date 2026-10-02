// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
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
  for (final early in [true, false]) {
    test(
        'event Future handles notification ${early ? 'before' : 'after'} app client construction returns',
        () async {
      final sdk = _MockSdk();
      when(() => sdk.configuration).thenReturn(DatadogConfiguration(
          clientToken: 'client-token', env: 'test', site: DatadogSite.us1));
      final flags = DatadogFlags();
      final firstFlags = Completer<FlagsClientEvent>();
      FlagDetails<bool>? details;
      FlagsClientEvent? firstEvent;
      var calls = 0;
      final plugin = DatadogFlagsPlugin(sdk,
          flags: flags,
          rumIntegrationEnabled: false,
          flagsConfiguration: DatadogFlagsConfiguration(
            onFirstFlags: (event) {
              calls++;
              firstFlags.complete(event);
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
      const context = FlagsEvaluationContext(targetingKey: 'example-user');
      Future<DatadogFlutterFlagsClient> construct() async {
        final client = plugin.sharedClient();
        if (early) await client.initialize(context);
        return client;
      }

      final client = await construct().timeout(const Duration(seconds: 1));
      expect(firstFlags.isCompleted, early);
      final handled = firstFlags.future.then((event) {
        firstEvent = event;
        details = client.getBooleanDetails(
            key: 'checkout.enabled', defaultValue: false);
      });
      if (!early) await client.initialize(context);
      await handled.timeout(const Duration(seconds: 1));
      expect(calls, 1);
      expect(firstEvent!.flagsChanged, ['checkout.enabled']);
      expect(details!.value, isTrue);
      expect(details!.variant, 'enabled');
      expect(details!.reason, 'TARGETING_MATCH');
      expect(details!.error, isNull);
      await client.initialize(
          const FlagsEvaluationContext(targetingKey: 'another-user'));
      expect(calls, 1);
    });
  }
}
