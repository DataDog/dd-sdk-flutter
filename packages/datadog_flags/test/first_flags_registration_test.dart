// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';
import 'package:datadog_flags/datadog_flags.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _context = FlagsEvaluationContext(targetingKey: 'user');
Future<DatadogFlags> _owner() async {
  final owner = DatadogFlags();
  await owner.enable(
      configuration: DatadogFlagsConfiguration(
    datadogConfig: const DatadogFlagsConfig(
        clientToken: 'token', env: 'test', site: DatadogFlagsSite.us1),
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
                  'doLog': false
                },
              }
            }
          }
        }),
        200)),
  ));
  addTearDown(owner.disable);
  return owner;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
      'each early and late registration receives retained event asynchronously once',
      () async {
    final client = (await _owner()).sharedClient();
    final events = <FlagsClientEvent>[];
    client.onFirstFlags(events.add);
    client.onFirstFlags(events.add);
    expect(events, isEmpty);
    await client.initialize(_context);
    expect(events, hasLength(2));
    expect(events[0], same(events[1]));
    await client.initialize(const FlagsEvaluationContext(targetingKey: 'next'));
    client.onFirstFlags(events.add);
    expect(events, hasLength(2));
    await _flush();
    expect(events, hasLength(3));
    expect(events.last, same(events.first));
  });
  test('cancel before install is per-registration and repeat-safe', () async {
    final client = (await _owner()).sharedClient();
    var calls = 0;
    void callback(FlagsClientEvent _) => calls++;
    final cancel = client.onFirstFlags(callback);
    client.onFirstFlags(callback);
    cancel();
    cancel();
    await client.initialize(_context);
    expect(calls, 1);
    client.onFirstFlags(callback);
    await _flush();
    expect(calls, 2);
  });
  test('cancel queued late delivery and after completed delivery', () async {
    final client = (await _owner()).sharedClient();
    await client.initialize(_context);
    var calls = 0;
    final cancel = client.onFirstFlags((_) => calls++);
    expect(calls, 0);
    cancel();
    await _flush();
    expect(calls, 0);
    final after = client.onFirstFlags((_) => calls++);
    await _flush();
    after();
    after();
    await _flush();
    expect(calls, 1);
  });
  test('running callback can cancel another queued callback and itself',
      () async {
    final client = (await _owner()).sharedClient();
    var calls = 0;
    late void Function() second;
    late void Function() first;
    first = client.onFirstFlags((_) {
      first();
      second();
      calls++;
    });
    second = client.onFirstFlags((_) => calls += 100);
    await client.initialize(_context);
    expect(calls, 1);
  });
  test('nested registration is another microtask and exceptions are isolated',
      () async {
    final client = (await _owner()).sharedClient();
    final order = <String>[];
    client.onFirstFlags((_) {
      order.add('first');
      client.onFirstFlags((_) => order.add('nested'));
      expect(order, ['first']);
      throw StateError('app');
    });
    client.onFirstFlags((_) => order.add('second'));
    await client.initialize(_context);
    await _flush();
    expect(order, ['first', 'second', 'nested']);
  });
  test('cancel all does not cancel initialize or erase retained event',
      () async {
    final client = (await _owner()).sharedClient();
    var canceledCalls = 0;
    final cancel = client.onFirstFlags((_) => canceledCalls++);
    cancel();
    await client.initialize(_context);
    final delivered = Completer<FlagsClientEvent>();
    client.onFirstFlags(delivered.complete);
    expect((await delivered.future).flagsChanged, ['checkout.enabled']);
    expect(canceledCalls, 0);
    expect(
        client
            .getBooleanDetails(key: 'checkout.enabled', defaultValue: false)
            .value,
        isTrue);
  });
  test(
      'reset and shutdown retain event but evaluations read current assignments',
      () async {
    final client = (await _owner()).sharedClient();
    await client.initialize(_context);
    await client.reset();
    await client.shutdown();
    final delivered = Completer<FlagsClientEvent>();
    client.onFirstFlags(delivered.complete);
    expect(delivered.isCompleted, isFalse);
    expect((await delivered.future).flagsChanged, ['checkout.enabled']);
    expect(
        client
            .getBooleanDetails(key: 'checkout.enabled', defaultValue: false)
            .error,
        FlagEvaluationError.providerNotReady);
  });
  test('noop never fabricates event and returns safe unregister', () async {
    final owner = DatadogFlags();
    final client = owner.sharedClient();
    var calls = 0;
    final cancel = client.onFirstFlags((_) => calls++);
    await client.initialize(_context);
    cancel();
    cancel();
    await _flush();
    expect(calls, 0);
  });
}
