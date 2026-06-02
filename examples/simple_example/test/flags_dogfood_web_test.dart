// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags/datadog_flags.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/flags/flags_demo_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('web local flags collector evaluates flags and counts emissions',
      () async {
    FlagsDemoRuntime? flagsRuntime;
    try {
      flagsRuntime = await FlagsDemoRuntime.create();
      await DatadogFlags.enable(configuration: flagsRuntime.configuration);
      final client = DatadogFlags.sharedClient();

      await client.setEvaluationContext(const DatadogFlagsEvaluationContext(
        targetingKey: 'flutter-user',
        attributes: {
          'plan': 'dogfood',
          'platform': 'flutter',
        },
      ));

      final enabled = client.getBooleanDetails(
        key: 'flutter.demo.enabled',
        defaultValue: false,
      );
      final title = client.getStringDetails(
        key: 'flutter.demo.title',
        defaultValue: 'Fallback title',
      );
      client.getIntegerDetails(key: 'flutter.demo.limit', defaultValue: 0);
      client.getDoubleDetails(key: 'flutter.demo.ratio', defaultValue: 0);
      client.getObjectDetails(key: 'flutter.demo.config', defaultValue: {});

      expect(enabled.value, isTrue);
      expect(enabled.variant, 'enabled');
      expect(title.value, 'Datadog Flags');
      expect(title.variant, 'copy-a');

      await Future<void>.delayed(Duration.zero);
      await client.flush();

      final collector = flagsRuntime.collector;
      expect(collector, isNotNull);
      expect(collector!.exposureCount, 5);
      expect(collector.evaluationRequestCount, 1);
      expect(collector.evaluationEventCount, 5);
    } finally {
      await DatadogFlags.disable();
      await flagsRuntime?.stop();
    }
  });
}
