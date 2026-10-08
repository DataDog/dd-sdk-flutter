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
import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/first_flags_test_client.dart';

// Test fixture deliberately constructs an SDK-internal event.
// ignore: invalid_use_of_internal_member
final _event = FlagsClientEvent(
    type: FlagsClientEventType.configurationChanged,
    flagsChanged: ['checkout.enabled']);

class _Sdk extends Mock implements DatadogSdk {}

class _Rum extends Mock implements DatadogRum {}

// Models the core's async, registration-zone and one-shot contract.
class _Delegate extends Fake implements DatadogFlagsClient {
  int registrations = 0;
  int initializations = 0;
  int cancellations = 0;
  bool throwRegistration = false;
  bool throwCancel = false;
  void Function(FlagsClientEvent)? listener;

  @override
  void Function() onFirstFlags(void Function(FlagsClientEvent) callback) {
    registrations++;
    if (throwRegistration) throw StateError('registration failed');
    listener = Zone.current.bindUnaryCallback(callback);
    return () {
      cancellations++;
      listener = null;
      if (throwCancel) throw StateError('cancellation failed');
    };
  }

  void emit({void Function()? afterDelivery}) {
    scheduleMicrotask(() {
      final callback = listener;
      listener = null;
      try {
        callback?.call(_event);
      } catch (_) {
        // The core isolates synchronous listener failures.
      }
      afterDelivery?.call();
    });
  }

  @override
  Future<void> initialize(FlagsEvaluationContext context) async {
    initializations++;
  }
}

// Integration tests yield a turn; unit tests control microtasks explicitly.
Future<void> _waitForEventLoop() => Future<void>.delayed(Duration.zero);

void main() {
  test('cancel before resolver completes never registers with the core', () {
    fakeAsync((async) {
      final resolving = Completer<DatadogFlagsClient>();
      final core = _Delegate();
      final client = createFirstFlagsTestClient(() => resolving.future);
      var calls = 0;
      final cancel = client.onFirstFlags((_) => calls++);
      cancel();
      cancel();
      resolving.complete(core);
      async.flushMicrotasks();
      expect(core.registrations, 0);
      expect(core.cancellations, 0);
      expect(calls, 0);
    });
  });

  test('resolved registration waits without starting initialization', () {
    fakeAsync((async) {
      final resolving = Completer<DatadogFlagsClient>();
      final core = _Delegate();
      final client = createFirstFlagsTestClient(() => resolving.future);
      var calls = 0;
      final cancel = client.onFirstFlags((_) => calls++);
      expect(core.registrations, 0);
      resolving.complete(core);
      async.flushMicrotasks();
      async.elapse(const Duration(days: 1));
      expect(core.registrations, 1);
      expect(core.initializations, 0);
      expect(calls, 0);
      cancel();
      cancel();
      expect(core.cancellations, 1);
    });
  });

  test('cancel after core enqueue suppresses delivery and unregisters once',
      () {
    fakeAsync((async) {
      final core = _Delegate();
      final client = createFirstFlagsTestClient(() async => core);
      var calls = 0;
      final cancel = client.onFirstFlags((_) => calls++);
      async.flushMicrotasks();
      core.emit();
      expect(calls, 0);
      cancel();
      cancel();
      async.flushMicrotasks();
      expect(core.cancellations, 1);
      expect(core.listener, isNull);
      expect(calls, 0);
    });
  });

  test('forwards within core delivery without another microtask', () {
    fakeAsync((async) {
      final core = _Delegate();
      final client = createFirstFlagsTestClient(() async => core);
      final order = <String>[];
      late void Function() cancel;
      cancel = client.onFirstFlags((_) {
        order.add('app');
        cancel();
      });
      async.flushMicrotasks();
      core.emit(afterDelivery: () => order.add('core returned'));
      expect(order, isEmpty);
      async.flushMicrotasks();
      expect(order, ['app', 'core returned']);
      cancel();
      expect(core.cancellations, 0);
    });
  });

  test('resolver and registration failures do not escape registration', () {
    fakeAsync((async) {
      final resolving = Completer<DatadogFlagsClient>();
      final client = createFirstFlagsTestClient(() => resolving.future);
      var calls = 0;
      final cancel = client.onFirstFlags((_) => calls++);
      resolving.completeError(StateError('enable failed'));
      async.flushMicrotasks();
      cancel();
      final core = _Delegate()..throwRegistration = true;
      final failed = createFirstFlagsTestClient(() async => core);
      final cancelFailed = failed.onFirstFlags((_) => calls++);
      async.flushMicrotasks();
      cancelFailed();
      expect(calls, 0);
    });
  });

  test('unregister isolates delegate errors and remains idempotent', () {
    fakeAsync((async) {
      final core = _Delegate()..throwCancel = true;
      final client = createFirstFlagsTestClient(() async => core);
      final cancel = client.onFirstFlags((_) {});
      async.flushMicrotasks();
      expect(cancel, returnsNormally);
      expect(cancel, returnsNormally);
      expect(core.cancellations, 1);
    });
  });

  test('core isolates app throws and completion clears unregister', () {
    fakeAsync((async) {
      final core = _Delegate();
      final client = createFirstFlagsTestClient(() async => core);
      var calls = 0;
      final cancel = client.onFirstFlags((_) {
        calls++;
        throw StateError('app');
      });
      async.flushMicrotasks();
      core.emit();
      async.flushMicrotasks();
      cancel();
      expect(calls, 1);
      expect(core.cancellations, 0);
    });
  });

  for (final late in [false, true]) {
    test(
        'real core ${late ? "late" : "early"} delivery preserves registration zone and reentrancy',
        () async {
      final owner = DatadogFlags();
      await owner.enable(
          configuration: DatadogFlagsConfiguration(
        datadogConfig: const DatadogFlagsConfig(
            clientToken: 'token', env: 'test', site: DatadogFlagsSite.us1),
        httpClient: MockClient((_) async =>
            http.Response('{"data":{"attributes":{"flags":{}}}}', 200)),
      ));
      addTearDown(owner.disable);
      final core = owner.sharedClient();
      if (late) await core.initialize(FlagsEvaluationContext.empty);
      fakeAsync((async) {
        final resolving = Completer<DatadogFlagsClient>();
        final client = createFirstFlagsTestClient(() => resolving.future);
        final order = <String>[];
        final zones = <Object?>[];
        final errors = <Object>[];
        final inventories = <List<String>?>[];
        var calls = 0;
        void duplicate(FlagsClientEvent _) => calls++;
        runZonedGuarded(() {
          client.onFirstFlags((event) {
            zones.add(Zone.current[#listener]);
            inventories.add(event.flagsChanged);
            order.add('first');
            client.onFirstFlags((_) => order.add('nested'));
            order.add('first returned');
            scheduleMicrotask(() => throw StateError('async app error'));
            throw StateError('sync app error');
          });
          final canceled = client.onFirstFlags(duplicate);
          client.onFirstFlags(duplicate);
          canceled();
          canceled();
        }, (error, stack) => errors.add(error),
            zoneValues: {#listener: 'registration'});
        runZoned(() {
          resolving.complete(core);
          if (!late) core.initialize(FlagsEvaluationContext.empty);
        }, zoneValues: {#listener: 'initializer'});
        expect(order, isEmpty);
        async.flushMicrotasks();
        expect(order, ['first', 'first returned', 'nested']);
        expect(zones, ['registration']);
        expect(inventories.single, isEmpty);
        expect(calls, 1);
        expect(errors, hasLength(1));
        expect(errors.single.toString(), contains('async app error'));
      });
    });
  }

  test('real core retained event binds wrapper before immediate evaluation',
      () async {
    final sdk = _Sdk();
    when(() => sdk.configuration).thenReturn(DatadogConfiguration(
        clientToken: 'token', env: 'test', site: DatadogSite.us1));
    final rum = _Rum();
    when(() => sdk.rum).thenReturn(rum);
    final owner = DatadogFlags();
    var requests = 0;
    final plugin = DatadogFlagsPlugin(sdk,
        flags: owner, rumIntegrationEnabled: true, flagsConfiguration:
            DatadogFlagsConfiguration(httpClient: MockClient((_) async {
      requests++;
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
    })));
    addTearDown(owner.disable);
    plugin.initialize();
    await plugin.ready;
    await owner
        .sharedClient()
        .initialize(const FlagsEvaluationContext(targetingKey: 'user'));
    final client = plugin.sharedClient();
    final events = <FlagsClientEvent>[];
    FlagDetails<bool>? details;
    client.onFirstFlags((event) {
      events.add(event);
      details = client.getBooleanDetails(
          key: 'checkout.enabled', defaultValue: false);
    });
    expect(events, isEmpty);
    await _waitForEventLoop();
    expect(events.single.flagsChanged, ['checkout.enabled']);
    expect(details!.value, isTrue);
    expect(details!.error, isNull);
    expect(requests, 1);
    verify(() => rum.addFeatureFlagEvaluation('checkout.enabled', 'enabled'))
        .called(1);
    final cancel = client.onFirstFlags(events.add);
    cancel();
    await _waitForEventLoop();
    expect(events, hasLength(1));
    final replay = Completer<FlagsClientEvent>();
    client.onFirstFlags(replay.complete);
    expect(replay.isCompleted, isFalse);
    expect(await replay.future, same(events.single));
    expect(requests, 1);
  });
}
