// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/force_gc.dart';
import '../test/helpers/first_flags_test_client.dart';

@pragma('vm:never-inline')
(WeakReference<Capture>, void Function()) register(
    DatadogFlutterFlagsClient client) {
  final capture = Capture();
  final reference = WeakReference(capture);
  return (reference, client.onFirstFlags((_) => capture.use()));
}

class _Delegate extends Fake implements DatadogFlagsClient {
  void Function(FlagsClientEvent)? listener;
  @override
  void Function() onFirstFlags(void Function(FlagsClientEvent) callback) {
    listener = callback;
    return () => listener = null;
  }
}

void main() {
  test('cancel releases forwarded capture while app microtask remains queued',
      () async {
    final core = _Delegate();
    final client = createFirstFlagsTestClient(() async => core);
    final registration = register(client);
    await Future<void>.delayed(Duration.zero);
    final held = <void Function()>[];
    runZoned(
        () => core.listener!(
            FlagsClientEvent(type: FlagsClientEventType.configurationChanged)),
        zoneSpecification:
            ZoneSpecification(scheduleMicrotask: (self, parent, zone, action) {
      held.add(() => zone.run(action));
    }));
    expect(held, hasLength(1));
    await collectGarbage();
    expect(hasTarget(registration.$1), isTrue);
    registration.$2();
    await collectGarbage();
    expect(hasTarget(registration.$1), isFalse);
    expect(core.listener, isNull);
    held.single();
  });

  test('cancel releases app capture while delegate Future remains pending',
      () async {
    final resolving = Completer<DatadogFlagsClient>();
    final client = createFirstFlagsTestClient(() => resolving.future);
    final registration = register(client);
    await collectGarbage();
    expect(hasTarget(registration.$1), isTrue);
    registration.$2();
    await collectGarbage();
    expect(hasTarget(registration.$1), isFalse);
    registration.$2();
    resolving.complete(DatadogFlags().sharedClient());
    await Future<void>.delayed(Duration.zero);
  });
}
