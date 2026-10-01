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

class MockSdk extends Mock implements DatadogSdk {}

class MockRum extends Mock implements DatadogRum {}

const context = FlagsEvaluationContext(targetingKey: 'alice');
final cacheJson = <String, Object?>{
  'flags': {
    'cached': {
      'allocationKey': 'allocation',
      'variationKey': 'variant',
      'variationType': 'boolean',
      'variationValue': true,
      'reason': 'TARGETING_MATCH',
      'doLog': true,
    },
  },
  'context': {'targetingKey': 'alice', 'attributes': <String, Object?>{}},
  'date': '2026-10-01T00:00:00.000Z',
};

class Store implements DatadogFlagsStore {
  @override
  Future<FlagsData?> read(String name) async => FlagsData.fromJson(cacheJson);
  @override
  Future<void> write(String name, FlagsData value) async {}
  @override
  Future<void> delete(String name) async {}
}

void main() {
  Future<DatadogFlagsPlugin> plugin({
    OnFirstFlags? callback,
    DatadogFlagsStore? store,
    Future<http.Response> Function(http.Request)? request,
    MockRum? rum,
  }) async {
    final sdk = MockSdk();
    when(() => sdk.configuration).thenReturn(
      DatadogConfiguration(
        clientToken: 'client-token',
        env: 'test',
        site: DatadogSite.us1,
      ),
    );
    when(() => sdk.rum).thenReturn(rum);
    final core = DatadogFlags();
    final plugin = DatadogFlagsPlugin(
      sdk,
      flags: core,
      rumIntegrationEnabled: true,
      flagsConfiguration: DatadogFlagsConfiguration(
        onFirstFlags: callback,
        store: store,
        httpClient: MockClient(
          request ??
              (_) async => http.Response(
                    jsonEncode({
                      'data': {
                        'attributes': {'flags': cacheJson['flags']},
                      },
                    }),
                    200,
                  ),
        ),
      ),
    );
    plugin.initialize();
    await plugin.ready;
    addTearDown(() async {
      plugin.shutdown();
      await core.disable();
    });
    return plugin;
  }

  test(
      'default config hook receives public usable wrapper before network completion',
      () async {
    final network = Completer<http.Response>();
    final delivered = Completer<void>();
    final rum = MockRum();
    late DatadogFlutterFlagsClient client;
    var calls = 0;
    final integration = await plugin(
      store: Store(),
      rum: rum,
      request: (_) => network.future,
      callback: (received, event) {
        calls++;
        expect(identical(received, client), isTrue);
        expect(received, isA<DatadogFlutterFlagsClient>());
        expect(event.flagsChanged, ['cached']);
        expect(event.providerName, 'Datadog');
        expect(
          received.getBooleanDetails(key: 'cached', defaultValue: false).value,
          isTrue,
        );
        delivered.complete();
      },
    );
    client = integration.sharedClient(
      onFirstFlags: (_, __) => fail('eager default ignores late registration'),
    );
    var completed = false;
    final initial = client.initialize(context).then((_) => completed = true);
    await delivered.future;
    expect(completed, isFalse);
    verify(() => rum.addFeatureFlagEvaluation('cached', 'variant')).called(1);
    network.complete(
      http.Response(
        jsonEncode({
          'data': {
            'attributes': {'flags': {}},
          },
        }),
        200,
      ),
    );
    await initial;
    expect(calls, 1);
  });

  test(
      'named override replaces fallback, keeps wrapper identity and ignores duplicate registration',
      () async {
    final seen = <String>[];
    final integration = await plugin(
      callback: (client, _) => seen.add('config:${client.name}'),
    );
    late DatadogFlutterFlagsClient named;
    named = integration.sharedClient(
      name: 'named',
      onFirstFlags: (received, _) {
        expect(identical(received, named), isTrue);
        expect(
          received.getBooleanDetails(key: 'cached', defaultValue: false).value,
          isTrue,
        );
        seen.add('named');
      },
    );
    expect(
      identical(
        named,
        integration.sharedClient(
          name: 'named',
          onFirstFlags: (_, __) => fail('late'),
        ),
      ),
      isTrue,
    );
    await named.initialize(context);
    await named.reset();
    await named.initialize(context);
    await integration.sharedClient(name: 'inherited').initialize(context);
    expect(seen, ['named', 'config:inherited']);
  });

  test(
    'wrapper callback can reset and reinitialize without rearming',
    () async {
      var calls = 0;
      final reentered = Completer<void>();
      final integration = await plugin(
        callback: (client, _) async {
          calls++;
          await client.reset();
          await client.initialize(
            const FlagsEvaluationContext(targetingKey: 'bob'),
          );
          reentered.complete();
        },
      );
      await integration.sharedClient().initialize(context);
      await reentered.future;
      expect(calls, 1);
    },
  );

  test(
    'wrapper callback can shut down and throw without failing initialization',
    () async {
      final stopped = Completer<void>();
      final integration = await plugin(
        callback: (client, _) async {
          await client.shutdown();
          stopped.complete();
          throw StateError('application callback');
        },
      );
      await integration.sharedClient().initialize(context);
      await stopped.future;
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'shutdown while delegate resolution is pending suppresses hook',
    () async {
      var calls = 0;
      final integration = await plugin(callback: (_, __) => calls++);
      final client = integration.sharedClient();
      final initial = client.initialize(context);
      await client.shutdown();
      await initial;
      expect(calls, 0);
    },
  );

  test('plugin shutdown suppresses in-flight callbacks', () async {
    var calls = 0;
    final network = Completer<http.Response>();
    final started = Completer<void>();
    final integration = await plugin(
      callback: (_, __) => calls++,
      request: (_) {
        started.complete();
        return network.future;
      },
    );
    final initial = integration.sharedClient().initialize(context);
    await started.future;
    integration.shutdown();
    network.complete(
      http.Response(
        jsonEncode({
          'data': {
            'attributes': {'flags': {}},
          },
        }),
        200,
      ),
    );
    await initial;
    expect(calls, 0);
  });

  test('empty configuration hook itself emits no RUM tagging', () async {
    final rum = MockRum();
    final events = <FlagsClientEvent>[];
    final integration = await plugin(
      rum: rum,
      callback: (_, event) => events.add(event),
      request: (_) async => http.Response(
        jsonEncode({
          'data': {
            'attributes': {'flags': {}},
          },
        }),
        200,
      ),
    );
    await integration.sharedClient().initialize(context);
    expect(events.single.flagsChanged, isEmpty);
    verifyNever(() => rum.addFeatureFlagEvaluation(any(), any()));
  });
}
