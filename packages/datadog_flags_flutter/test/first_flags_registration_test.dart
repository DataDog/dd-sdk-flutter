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
import 'helpers/first_flags_test_client.dart';

final _event = FlagsClientEvent(
    type: FlagsClientEventType.configurationChanged,
    flagsChanged: ['checkout.enabled']);

class _Sdk extends Mock implements DatadogSdk {}

class _Rum extends Mock implements DatadogRum {}

class _Delegate extends Fake implements DatadogFlagsClient {
  int registrations = 0;
  int initializations = 0;
  int cancellations = 0;
  void Function(FlagsClientEvent)? listener;
  void Function()? duringRegistration;
  bool throwCancel = false;
  @override
  void Function() onFirstFlags(void Function(FlagsClientEvent) callback) {
    registrations++;
    listener = callback;
    duringRegistration?.call();
    return () {
      cancellations++;
      listener = null;
      if (throwCancel) throw StateError('custom');
    };
  }

  @override
  Future<void> initialize(FlagsEvaluationContext context) async {
    initializations++;
  }

  @override
  Future<void> shutdown() async {}
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('cancel while resolving releases registration without forwarding',
      () async {
    final resolving = Completer<DatadogFlagsClient>();
    final core = _Delegate();
    final client = createFirstFlagsTestClient(() => resolving.future);
    var calls = 0;
    final cancel = client.onFirstFlags((_) => calls++);
    cancel();
    cancel();
    resolving.complete(core);
    await _flush();
    expect(core.registrations, 0);
    expect(calls, 0);
  });
  test('resolver failure is contained and initialization keeps original error',
      () async {
    final resolving = Completer<DatadogFlagsClient>();
    final client = createFirstFlagsTestClient(() => resolving.future);
    var calls = 0;
    final cancel = client.onFirstFlags((_) => calls++);
    resolving.completeError(StateError('enable failed'));
    await _flush();
    cancel();
    await expectLater(
        client.initialize(FlagsEvaluationContext.empty), throwsStateError);
    expect(calls, 0);
  });
  test(
      'cancel after forwarding unregisters once and suppresses queued app work',
      () async {
    final core = _Delegate();
    final client = createFirstFlagsTestClient(() async => core);
    var calls = 0;
    final cancel = client.onFirstFlags((_) => calls++);
    await _flush();
    core.listener!(_event);
    expect(calls, 0);
    cancel();
    cancel();
    await _flush();
    expect(core.cancellations, 1);
    expect(core.listener, isNull);
    expect(calls, 0);
  });
  test(
      'custom synchronous delivery remains microtask and duplicates do not redeliver',
      () async {
    final core = _Delegate();
    final client = createFirstFlagsTestClient(() async => core);
    var calls = 0;
    var duringCalls = -1;
    core.duringRegistration = () {
      core.listener!(_event);
      core.listener!(_event);
      duringCalls = calls;
    };
    final cancel = client.onFirstFlags((_) => calls++);
    expect(calls, 0);
    await _flush();
    expect(calls, 1);
    expect(duringCalls, 0);
    cancel();
    cancel();
    expect(core.cancellations, 0);
  });
  test('cancel during custom registration cancels token obtained afterward',
      () async {
    final core = _Delegate()..throwCancel = true;
    final client = createFirstFlagsTestClient(() async => core);
    var calls = 0;
    late void Function() cancel;
    core.duringRegistration = () {
      core.listener!(_event);
      cancel();
    };
    cancel = client.onFirstFlags((_) => calls++);
    await _flush();
    cancel();
    expect(core.cancellations, 1);
    expect(calls, 0);
  });
  test('callback exception does not produce failed SDK Future', () async {
    final core = _Delegate();
    final client = createFirstFlagsTestClient(() async => core);
    client.onFirstFlags((_) => throw StateError('app'));
    await _flush();
    core.listener!(_event);
    await _flush();
  });
  test('shutdown overlap forwards once to resolved core without migration',
      () async {
    final resolving = Completer<DatadogFlagsClient>();
    final coreA = _Delegate();
    final coreB = _Delegate();
    var resolutions = 0;
    final client = createFirstFlagsTestClient(() {
      resolutions++;
      return resolving.future;
    });
    var calls = 0;
    final cancel = client.onFirstFlags((_) => calls++);
    await client.shutdown();
    resolving.complete(coreA);
    await _flush();
    expect(coreA.registrations, 1);
    expect(coreB.registrations, 0);
    expect(resolutions, 1);
    coreA.listener!(_event);
    await _flush();
    expect(calls, 1);
    cancel();
    final replacement = createFirstFlagsTestClient(() async => coreB);
    final cancelB = replacement.onFirstFlags((_) {});
    await _flush();
    expect(coreB.registrations, 1);
    cancelB();
  });
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
    await _flush();
    expect(events.single.flagsChanged, ['checkout.enabled']);
    expect(details!.value, isTrue);
    expect(details!.error, isNull);
    expect(requests, 1);
    verify(() => rum.addFeatureFlagEvaluation('checkout.enabled', 'enabled'))
        .called(1);
    final cancel = client.onFirstFlags(events.add);
    cancel();
    await _flush();
    expect(events, hasLength(1));
  });
  test('registering before plugin readiness does not initialize flags',
      () async {
    final resolving = Completer<DatadogFlagsClient>();
    final core = _Delegate();
    final client = createFirstFlagsTestClient(() => resolving.future);
    var calls = 0;
    client.onFirstFlags((_) => calls++);
    expect(core.registrations, 0);
    resolving.complete(core);
    await _flush();
    expect(core.registrations, 1);
    expect(core.initializations, 0);
    expect(calls, 0);
  });
}
