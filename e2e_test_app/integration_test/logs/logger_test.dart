// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:e2e_test_app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test_utils.dart';

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

  /// - data monitor:
  /// ```logs
  /// $monitor_id = logs_logger_debug_log_data
  /// $monitor_name = "[RUM] [Flutter] Nightly - logger - debug logs: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:com.datadog.flutter.nightly @test_method_name:\\\"logger - debug logs\\\" status:debug\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm
  /// $feature = logs
  /// $monitor_id = logs_logger_debug_log_performance
  /// $monitor_name = "[RUM] [Flutter] Nightly Performance - logger - debug logs: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,resource_name:\\\"logger - debug logs\\\",service:com.datadog.flutter.nightly} > 0.024"
  /// ```
  testWidgets('logger - debug logs', (WidgetTester tester) async {
    await measure(tester.testDescription, () async {
      await DatadogSdk.instance.logs
          ?.debug('fake message', {'test_method_name': tester.testDescription});
    });
  });

  ///
  /// - data monitor:
  /// ```logs
  /// $monitor_id = logs_logger_debug_info
  /// $monitor_name = "[RUM] [Flutter] Nightly - logger - debug info: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:com.datadog.flutter.nightly @test_method_name:\\\"logger - debug info\\\" status:debug\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm
  /// $feature = logs
  /// $monitor_id = logs_logger_debug_info
  /// $monitor_name = "[RUM] [Flutter] Nightly Performance - logger - debug info: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,resource_name:\\\"logger - debug info\\\",service:com.datadog.flutter.nightly} > 0.024"
  /// ```
  testWidgets('logger - debug info', (WidgetTester tester) async {
    await measure(tester.testDescription, () async {
      await DatadogSdk.instance.logs?.info(
          'fake info message', {'test_method_name': tester.testDescription});
    });
  });
}
