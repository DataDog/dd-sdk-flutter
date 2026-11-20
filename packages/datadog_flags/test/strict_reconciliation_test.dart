import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/flags_store.dart'
    show InMemoryDatadogFlagsStore;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const context = FlagsEvaluationContext(targetingKey: 'alice');
String packet(String value) => jsonEncode({
      'data': {
        'attributes': {
          'createdAt': DateTime.now().toIso8601String(),
          'flags': {
            'test': {
              'allocationKey': 'a',
              'variationKey': value,
              'variationType': 'string',
              'variationValue': value,
              'reason': 'TARGETING_MATCH',
              'doLog': false
            },
          }
        }
      },
    });
Future<DatadogFlagsClient> clientFor(http.Client transport,
    {DatadogFlagsStore? store}) async {
  final sdk = DatadogFlags();
  await sdk.enable(
      configuration: DatadogFlagsConfiguration(
    datadogConfig: const DatadogFlagsConfig(
        clientToken: 'pubtest', env: 'test', site: DatadogFlagsSite.us1),
    initializationTimeout: null,
    store: store,
    httpClient: transport,
    trackEvaluations: false,
    trackExposures: false,
  ));
  addTearDown(sdk.disable);
  return sdk.sharedClient();
}

class PendingStore implements DatadogFlagsStore {
  final started = Completer<void>();
  final release = Completer<void>();
  var writes = 0;
  @override
  Future<FlagsData?> read(String name) async => null;
  @override
  Future<void> delete(String name) async {}
  @override
  Future<void> write(String name, FlagsData data) async {
    if (writes++ == 0) {
      started.complete();
      await release.future;
    }
  }
}

void main() {
  test(
      'strict async initialize waits and reconciles identical contexts every time',
      () async {
    final responses = [Completer<http.Response>(), Completer<http.Response>()];
    var calls = 0;
    final client =
        await clientFor(MockClient((_) => responses[calls++].future));
    for (var i = 0; i < 2; i++) {
      var completed = false;
      final operation =
          client.initialize(context, throwOnFailure: true).then((_) {
        completed = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(calls, i + 1);
      expect(completed, isFalse);
      responses[i].complete(http.Response(packet('value-$i'), 200));
      await operation;
      expect(client.getStringDetails(key: 'test', defaultValue: '').value,
          'value-$i');
    }
  });
  test(
      'strict failure is observable and retry succeeds; default remains fail-soft',
      () async {
    var status = 503;
    final client = await clientFor(MockClient((_) async =>
        http.Response(status == 200 ? packet('ok') : 'failure', status)));
    await expectLater(client.initialize(context), completes);
    await expectLater(client.initialize(context, throwOnFailure: true),
        throwsA(isA<FlagsException>()));
    status = 200;
    await client.initialize(context, throwOnFailure: true);
    expect(client.getStringDetails(key: 'test', defaultValue: '').value, 'ok');
  });
  test('strict malformed response fails instead of silently completing',
      () async {
    final client = await clientFor(
        MockClient((_) async => http.Response('not json', 200)));
    await expectLater(
        client.initialize(context, throwOnFailure: true), throwsA(anything));
  });
  test('strict superseded operation cannot report success', () async {
    final firstResponse = Completer<http.Response>();
    var calls = 0;
    final client = await clientFor(MockClient((_) async => calls++ == 0
        ? firstResponse.future
        : http.Response(packet('bob'), 200)));
    final first = client.initialize(context, throwOnFailure: true);
    final failed = expectLater(first, throwsA(isA<FlagsException>()));
    await Future<void>.delayed(Duration.zero);
    await client.initialize(const FlagsEvaluationContext(targetingKey: 'bob'),
        throwOnFailure: true);
    firstResponse.complete(http.Response(packet('alice'), 200));
    await failed;
    expect(client.getStringDetails(key: 'test', defaultValue: '').value, 'bob');
  });
  test(
      'strict reconciliation rejects fetch failure even with matching stored assignments',
      () async {
    final store = InMemoryDatadogFlagsStore();
    var failed = false;
    final client = await clientFor(
        MockClient((_) async => failed
            ? http.Response('failed', 503)
            : http.Response(packet('cached'), 200)),
        store: store);
    await client.initialize(context, throwOnFailure: true);
    failed = true;
    await expectLater(client.initialize(context, throwOnFailure: true),
        throwsA(isA<FlagsException>()));
    // Default cache fallback is unchanged for callers that choose it.
    await expectLater(client.initialize(context), completes);
    expect(
        client.getStringDetails(key: 'test', defaultValue: '').value, 'cached');
  });
  test(
      'strict operation superseded during cache write fails and preserves newer state',
      () async {
    final store = PendingStore();
    var calls = 0;
    final client = await clientFor(
        MockClient((_) async => http.Response(packet('value-${calls++}'), 200)),
        store: store);
    final first = client.initialize(context, throwOnFailure: true);
    final failure = expectLater(first, throwsA(isA<FlagsException>()));
    await store.started.future;
    final second = client.initialize(
        const FlagsEvaluationContext(targetingKey: 'bob'),
        throwOnFailure: true);
    await Future<void>.delayed(Duration.zero);
    store.release.complete();
    await failure;
    await second;
    expect(client.getStringDetails(key: 'test', defaultValue: '').value,
        'value-1');
  });
  test('strict disabled client fails', () async {
    final client = DatadogFlags().sharedClient();
    await expectLater(client.initialize(context, throwOnFailure: true),
        throwsA(isA<FlagsException>()));
  });
}
