// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:e2e_test_app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test_utils.dart';

/// ```global
/// $service = com.datadog.flutter.nightly
/// $feature = flutter_traces_config
/// $monitor_name_prefix = [RUM] [Flutter (${{variant:-global}})] Nightly - ${{test_description}}
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final datadog = DatadogSdk.instance;

  setUp(() async {
    app.main();
  });

  tearDown(() async {
    await datadog.flushAndDeinitialize();
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_set_service_name
  /// ```
  ///
  /// ```apm(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of hits is below expected value"
  /// $monitor_query = "sum(last_1d):avg:flutter_${{variant}}_traces_set_service_name.hits{service:com.datadog.flutter.nightly.custom,env:instrumentation}.as_count() < 1"
  /// $monitor_threshold = 1
  /// ```
  testWidgets('traces config - set service name', (tester) async {
    await initializeDatadog(
      (config) => config.additionalConfig[DatadogConfigKey.serviceName] =
          'com.datadog.flutter.nightly.custom',
    );

    final span =
        startSpan('traces_${Platform.operatingSystem}_set_service_name');
    span.finish();
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_bundle_with_rum_enabled
  /// ```
  ///
  /// - data monitor: (it uses `flutter_${{variant}}_traces_bundle_with_rum_enabled` metric defined in "APM > Generate Metrics > Custom Span Metrics")
  /// ```apm(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of hits is below expected value"
  /// $monitor_query = "sum(last_1d):avg:flutter_${{variant}}_traces_bundle_with_rum_enabled.hits_with_proper_payload{*}.as_count() < 1"
  /// $monitor_threshold = 1
  /// ```
  testWidgets('traces config - bundle with rum enabled', (tester) async {
    await initializeDatadog(
      (config) => config.tracingConfiguration!.bundleWithRum = true,
    );

    final viewKey = randomString();

    datadog.rum?.startView(viewKey);
    final span = startSpan('traces_config_bundle_with_rum_enabled');
    span.finish();

    datadog.rum?.stopView(viewKey);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_bundle_with_rum_disabled
  /// ```
  ///
  /// - data monitor: (it uses `flutter_${{variant}}_traces_bundle_with_rum_disabled` metric defined in "APM > Generate Metrics > Custom Span Metrics")
  /// ```apm(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of hits is above expected value"
  /// $monitor_query = "sum(last_1d):avg:flutter_${{variant}}_traces_bundle_with_rum_enabled.hits_with_proper_payload{*}.as_count() > 0"
  /// $monitor_threshold = 0
  /// ```
  testWidgets('traces config - bundle with rum disabled', (tester) async {
    await initializeDatadog(
      (config) => config.tracingConfiguration!.bundleWithRum = false,
    );

    final viewKey = randomString();

    datadog.rum?.startView(viewKey);
    final span = startSpan('traces_config_bundle_with_rum_disabled');
    span.finish();

    datadog.rum?.stopView(viewKey);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_set_user_info
  /// ```
  ///
  /// - data monitor: (it uses `flutter_${{variant}}_traces_set_user_info` metric defined in "APM > Generate Metrics > Custom Span Metrics")
  /// ```apm(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of hits is below expected value"
  /// $monitor_query = "sum(last_1d):avg:flutter_${{variant}}_traces_set_user_info.hits_with_proper_payload{*}.as_count() < 1"
  /// $monitor_threshold = 1
  /// ```
  testWidgets('traces config - set_user_info', (tester) async {
    await initializeDatadog();

    datadog.setUserInfo(
      id: 'some-id-${randomString()}',
      name: 'some-name-${randomString()}',
      email: 'some-email@${randomString()}.com',
      extraInfo: {'level1': randomString(), 'another.level2': randomString()},
    );
    final span = startSpan('traces_config_set_user_info');
    span.finish();
  });
}
