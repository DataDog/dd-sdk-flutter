// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:e2e_test_app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test_utils.dart';

/// ```global
/// $service = com.datadog.flutter.nightly
/// $feature = flutter_logs
/// $monitor_name_prefix = [RUM] [Flutter (${{variant:-global}})] Nightly
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // TODO: Delete all SDK data
    await initializeDatadog();
  });

  setUp(() async {
    app.main();
  });

  tearDownAll(() async {
    await DatadogSdk.instance.flushAndDeinitialize();
  });

  // Convenience field
  final datadog = DatadogSdk.instance;

  /// ```global
  /// $monitor_prefix = ${{feature}}_debug_log
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" status:debug @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm
  /// $monitor_id = ${{monitor_prefix}}_performance
  /// $monitor_name = "${{monitor_name_prefix}} Performance - ${{test_description}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,resource_name:\\\"${{test_description}}\\\",service:${{service}}} > 0.024"
  /// ```
  testWidgets('logger - debug logs', (WidgetTester tester) async {
    await measure(tester.testDescription, () async {
      await datadog.logs?.debug('fake message', {
        'test_method_name': tester.testDescription,
        'operating_system': Platform.operatingSystem
      });
    });
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_info_log
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" status:info @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm
  /// $feature = logs
  /// $monitor_id = ${{monitor_prefix}}_performance
  /// $monitor_name = "${{monitor_name_prefix}} Performance - ${{test_description}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,resource_name:\\\"${{test_description}}\\\",service:${{test_description}}} > 0.024"
  /// ```
  testWidgets('logger - info logs', (WidgetTester tester) async {
    await measure(tester.testDescription, () async {
      await datadog.logs?.info('fake info message', {
        'test_method_name': tester.testDescription,
        'operating_system': Platform.operatingSystem,
      });
    });
  });
}
