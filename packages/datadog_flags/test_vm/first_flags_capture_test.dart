// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

@TestOn('vm')
library;

import 'dart:async';
import 'package:datadog_flags/datadog_flags.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'helpers/force_gc.dart';

@pragma('vm:never-inline')
(WeakReference<Capture>, void Function()) register(DatadogFlagsClient client) {
  final capture = Capture();
  final reference = WeakReference(capture);
  final unregister = client.onFirstFlags((_) => capture.use());
  return (reference, unregister);
}

void main() {
  for (final queued in [false, true]) {
    test(
        'cancel releases ${queued ? 'queued' : 'pending'} captures while token remains live',
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
      final client = owner.sharedClient();
      if (queued) await client.initialize(FlagsEvaluationContext.empty);
      final held = <void Function()>[];
      final registration = runZoned(() => register(client), zoneSpecification:
          ZoneSpecification(scheduleMicrotask: (self, parent, zone, action) {
        held.add(() => zone.run(action));
      }));
      expect(held, hasLength(queued ? 1 : 0));
      await collectGarbage();
      expect(hasTarget(registration.$1), isTrue);
      registration.$2();
      await collectGarbage();
      expect(hasTarget(registration.$1), isFalse);
      registration.$2();
      // The queued closure is still retained during collection above.
      for (final action in held) {
        action();
      }
    });
  }
}
