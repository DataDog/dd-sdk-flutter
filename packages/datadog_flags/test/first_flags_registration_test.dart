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
import 'package:fake_async/fake_async.dart';

const _context = FlagsEvaluationContext(targetingKey: 'user');
Future<DatadogFlags> _owner(
    {DatadogFlagsStore? store, void Function()? onRequest}) async {
  final owner = DatadogFlags();
  await owner.enable(
      configuration: DatadogFlagsConfiguration(
    datadogConfig: const DatadogFlagsConfig(
        clientToken: 'token', env: 'test', site: DatadogFlagsSite.us1),
    store: store,
    httpClient: MockClient((_) async {
      onRequest?.call();
      return http.Response(
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
          200);
    }),
  ));
  addTearDown(owner.disable);
  return owner;
}

// Yield to the next event-loop turn so queued callback microtasks can run.
Future<void> _waitForEventLoop() => Future<void>.delayed(Duration.zero);
void main() {
  for (final late in [false, true]) {
    test(
        '${late ? "late" : "early"} callback uses registration zone and routes async errors there',
        () async {
      final client = (await _owner()).sharedClient();
      if (late) await client.initialize(_context);
      Object? observed;
      final errors = <Object>[];
      runZonedGuarded(() {
        client.onFirstFlags((_) {
          observed = Zone.current[#listenerZone];
          scheduleMicrotask(() => throw StateError('async listener error'));
          throw StateError('isolated synchronous listener error');
        });
      }, (error, stack) => errors.add(error),
          zoneValues: {#listenerZone: 'registration'});
      if (!late) {
        await runZoned(() => client.initialize(_context),
            zoneValues: {#listenerZone: 'initialization'});
      }
      await _waitForEventLoop();
      expect(observed, 'registration');
      expect(errors, hasLength(1));
      expect(errors.single.toString(), contains('async listener error'));
    });
  }

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
    await _waitForEventLoop();
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
    await _waitForEventLoop();
    expect(calls, 2);
  });
  test('late replay uses one microtask and queued cancellation is idempotent',
      () async {
    final client = (await _owner()).sharedClient();
    await client.initialize(_context);
    fakeAsync((async) {
      final events = <FlagsClientEvent>[];
      final canceled = client.onFirstFlags(events.add);
      expect(async.microtaskCount, 1);
      expect(events, isEmpty);
      canceled();
      canceled();
      async.flushMicrotasks();
      expect(events, isEmpty);
      final completed = client.onFirstFlags(events.add);
      expect(async.microtaskCount, 1);
      async.flushMicrotasks();
      completed();
      completed();
      expect(events.single.flagsChanged, ['checkout.enabled']);
    });
  });

  test('pending duplicate functions are independent registrations', () async {
    final client = (await _owner()).sharedClient();
    fakeAsync((async) {
      var calls = 0;
      void callback(FlagsClientEvent _) => calls++;
      final first = client.onFirstFlags(callback);
      final second = client.onFirstFlags(callback);
      first();
      first();
      client.initialize(_context);
      expect(calls, 0);
      async.flushMicrotasks();
      expect(calls, 1);
      second();
      async.flushMicrotasks();
      expect(calls, 1);
    });
  });

  test(
      'registration without initialization performs no request or notification',
      () async {
    var requests = 0;
    final client = (await _owner(onRequest: () => requests++)).sharedClient();
    fakeAsync((async) {
      var calls = 0;
      final cancel = client.onFirstFlags((_) => calls++);
      async.flushMicrotasks();
      async.elapse(const Duration(days: 1));
      expect(requests, 0);
      expect(calls, 0);
      cancel();
      cancel();
    });
  });

  test(
      'canceled initialization with empty disk result sends no request or event',
      () async {
    late Completer<FlagsData?> disk;
    var requests = 0;
    final client = (await _owner(
      store: _PendingStore(() => disk.future),
      onRequest: () => requests++,
    ))
        .sharedClient();
    fakeAsync((async) {
      var calls = 0;
      var initialized = false;
      disk = Completer<FlagsData?>();
      final cancel = client.onFirstFlags((_) => calls++);
      client.initialize(_context).then((_) => initialized = true);
      client.shutdown();
      disk.complete(null);
      async.flushMicrotasks();
      expect(initialized, isTrue);
      expect(requests, 0);
      expect(calls, 0);
      cancel();
      cancel();
    });
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
  for (final error in [Exception('app'), StateError('app'), Object()]) {
    test(
        'nested registration is another microtask and ${error.runtimeType} is isolated',
        () async {
      final client = (await _owner()).sharedClient();
      final order = <String>[];
      client.onFirstFlags((_) {
        order.add('first');
        client.onFirstFlags((_) => order.add('nested'));
        expect(order, ['first']);
        throw error;
      });
      client.onFirstFlags((_) => order.add('second'));
      await client.initialize(_context);
      await _waitForEventLoop();
      expect(order, ['first', 'second', 'nested']);
    });
  }
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
    await _waitForEventLoop();
    expect(calls, 0);
  });
}

class _PendingStore implements DatadogFlagsStore {
  final Future<FlagsData?> Function() load;
  _PendingStore(this.load);
  @override
  Future<FlagsData?> read(String name) => load();
  @override
  Future<void> write(String name, FlagsData data) async {}
  @override
  Future<void> delete(String name) async {}
}
