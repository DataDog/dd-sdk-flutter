// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

class _MockSdk extends Mock implements DatadogSdk {}

class _MockRum extends Mock implements DatadogRum {}

class _Store implements DatadogFlagsStore {
  final Future<FlagsData?> Function() load;
  _Store(this.load);
  @override
  Future<FlagsData?> read(String name) => load();
  @override
  Future<void> write(String name, FlagsData data) async {}
  @override
  Future<void> delete(String name) async {}
}

Map<String, Object?> _flag() => {
      'allocationKey': 'allocation',
      'variationKey': 'enabled',
      'variationType': 'boolean',
      'variationValue': true,
      'reason': 'TARGETING_MATCH',
      'doLog': false,
    };

void main() {
  test(
      'queued delivery retains originating wrapper across shutdown and reenable',
      () async {
    final sdk = _MockSdk();
    when(() => sdk.configuration).thenReturn(DatadogConfiguration(
        clientToken: 'token', env: 'test', site: DatadogSite.us1));
    final flags = DatadogFlags();
    DatadogFlagsClient? notified;
    DatadogFlutterFlagsClient? replacement;
    var interrupted = false;
    final plugin = DatadogFlagsPlugin(sdk,
        flags: flags,
        rumIntegrationEnabled: false,
        flagsConfiguration: DatadogFlagsConfiguration(
          httpClient: MockClient((_) async => http.Response(
              jsonEncode({
                'data': {
                  'attributes': {
                    'flags': {'checkout.enabled': _flag()}
                  }
                },
              }),
              200)),
          onFirstFlags: (client, _) => notified = client,
        ));
    addTearDown(flags.disable);
    plugin.initialize();
    await plugin.ready;
    final original = plugin.sharedClient();
    await runZoned(
        () => original.initialize(
            const FlagsEvaluationContext(targetingKey: 'example-user')),
        zoneSpecification: ZoneSpecification(
            scheduleMicrotask: (self, parent, zone, callback) {
      // Interleave exactly after event capture, before queued user delivery.
      if (!interrupted &&
          StackTrace.current.toString().contains('FlagsRepository._install')) {
        interrupted = true;
        plugin.shutdown();
        plugin.initialize();
        replacement = plugin.sharedClient();
      }
      parent.scheduleMicrotask(zone, callback);
    }));
    await plugin.ready;
    expect(interrupted, isTrue);
    expect(notified, same(original));
    expect(replacement, isNot(same(original)));
    expect(plugin.sharedClient(), same(replacement));
    expect(
        replacement!
            .getBooleanDetails(key: 'checkout.enabled', defaultValue: false)
            .error,
        FlagEvaluationError.providerNotReady);
    await replacement!.initialize(
        const FlagsEvaluationContext(targetingKey: 'replacement-user'));
    expect(notified, same(replacement));
    expect(
        replacement!
            .getBooleanDetails(key: 'checkout.enabled', defaultValue: false)
            .value,
        isTrue);
  });

  for (final mode in [
    'synchronous cache',
    'asynchronous cache',
    'empty cache',
    'missing cache'
  ]) {
    test('$mode delivers registered usable Flutter wrapper and permits reentry',
        () async {
      final sdk = _MockSdk();
      final rum = _MockRum();
      when(() => sdk.configuration).thenReturn(DatadogConfiguration(
          clientToken: 'token', env: 'test', site: DatadogSite.us1));
      when(() => sdk.rum).thenReturn(rum);
      final flags = DatadogFlags();
      final delivered = Completer<void>();
      final network = Completer<http.Response>();
      final data = FlagsData.fromJson({
        'context': {'targetingKey': 'example-user'},
        'date': '2026-10-01T00:00:00.000Z',
        'flags': mode == 'empty cache'
            ? <String, Object?>{}
            : {'checkout.enabled': _flag()},
      });
      final store = _Store(() => switch (mode) {
            'synchronous cache' || 'empty cache' => SynchronousFuture(data),
            'missing cache' => SynchronousFuture(null),
            _ => Future<FlagsData?>.delayed(Duration.zero, () => data),
          });
      var calls = 0;
      DatadogFlagsClient? notifiedClient;
      FlagDetails<bool>? early;
      FlagsClientEvent? event;
      Future<void>? reentry;
      final plugin = DatadogFlagsPlugin(sdk,
          flags: flags,
          rumIntegrationEnabled: true,
          flagsConfiguration: DatadogFlagsConfiguration(
            store: store,
            httpClient: MockClient((_) => network.future),
            onFirstFlags: (client, firstEvent) {
              calls++;
              notifiedClient = client;
              event = firstEvent;
              early = client.getBooleanDetails(
                  key: 'checkout.enabled', defaultValue: false);
              reentry = client.reset().then((_) => client.initialize(
                  const FlagsEvaluationContext(targetingKey: 'next-user')));
              delivered.complete();
            },
          ));
      addTearDown(flags.disable);
      plugin.initialize();
      await plugin.ready;
      // Start through core before creating a wrapper to exercise adapter binding.
      final core = flags.sharedClient(name: 'named');
      final initializing = core.initialize(
          const FlagsEvaluationContext(targetingKey: 'example-user'));
      final response = http.Response(
          jsonEncode({
            'data': {
              'attributes': {
                'flags': {'checkout.enabled': _flag()},
              }
            }
          }),
          200);
      if (mode == 'missing cache') network.complete(response);
      await delivered.future;
      expect(notifiedClient, same(plugin.sharedClient(name: 'named')));
      expect(notifiedClient, isA<DatadogFlutterFlagsClient>());
      expect(notifiedClient, isNot(same(core)));
      expect(early!.value, mode != 'empty cache');
      expect(event!.flagsChanged,
          mode == 'empty cache' ? isEmpty : ['checkout.enabled']);
      if (mode != 'empty cache') {
        expect(early!.error, isNull);
        verify(() =>
                rum.addFeatureFlagEvaluation('checkout.enabled', 'enabled'))
            .called(1);
      }
      if (!network.isCompleted) network.complete(response);
      await initializing;
      await reentry;
      expect(calls, 1);
    });
  }

  test('callback receives the usable registered Flutter client', () async {
    final sdk = _MockSdk();
    when(() => sdk.configuration).thenReturn(DatadogConfiguration(
        clientToken: 'client-token', env: 'test', site: DatadogSite.us1));
    final flags = DatadogFlags();
    DatadogFlagsClient? notifiedClient;
    FlagDetails<bool>? early;
    FlagsClientEvent? firstEvent;
    var calls = 0;
    final plugin = DatadogFlagsPlugin(sdk,
        flags: flags,
        rumIntegrationEnabled: false,
        flagsConfiguration: DatadogFlagsConfiguration(
          onFirstFlags: (client, event) {
            notifiedClient = client;
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
    final client = plugin.sharedClient();
    await client
        .initialize(const FlagsEvaluationContext(targetingKey: 'example-user'));
    expect(calls, 1);
    expect(notifiedClient, same(client));
    expect(notifiedClient, isA<DatadogFlutterFlagsClient>());
    expect(firstEvent!.flagsChanged, ['checkout.enabled']);
    expect(early!.value, isTrue);
    expect(early!.variant, 'enabled');
    expect(early!.reason, 'TARGETING_MATCH');
    expect(early!.error, isNull);
    await client
        .initialize(const FlagsEvaluationContext(targetingKey: 'another-user'));
    expect(calls, 1);
    expect(notifiedClient, same(client));
    expect(notifiedClient, isA<DatadogFlutterFlagsClient>());
  });
}
