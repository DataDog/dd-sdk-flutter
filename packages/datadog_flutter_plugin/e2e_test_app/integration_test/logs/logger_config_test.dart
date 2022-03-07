// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:e2e_test_app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test_utils.dart';

/// ```global
/// $service = com.datadog.flutter.nightly
/// $feature = flutter_logs_config
/// $monitor_name_prefix = [RUM] [Flutter (${{variant:-global}})] Nightly
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final datadog = DatadogSdk.instance;

  setUp(() {
    app.main();
  });

  tearDown(() async {
    await datadog.flushAndDeinitialize();
  });

  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{feature}}_set_service_name_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}}.custom @test_method_name:\\\"${{test_description}}\\\" @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  testWidgets('logger config - set service name', (tester) async {
    await initializeDatadog(
      (config) => config.additionalConfig[DatadogConfigKey.serviceName] =
          'com.datadog.flutter.nightly.custom',
    );

    sendRandomLog(tester);
  });

  // - data monitor:
  /// ```logs
  /// $monitor_id = ${{feature}}_send_network_info_enabled_ios
  /// $monitor_name = "[RUM] [Flutter (ios})] Nightly - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" @operating_system:ios @network.client.reachability:*\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  /// ```logs
  /// $monitor_id = ${{feature}}_send_network_info_enabled_android
  /// $monitor_name = "[RUM] [Flutter (android})] Nightly - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" @operating_system:android @network.client.connectivity:*\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  testWidgets('logger config - send network info enabled', (tester) async {
    await initializeDatadog(
      (config) => config.loggingConfiguration!.sendNetworkInfo = true,
    );

    sendRandomLog(tester);
  });

  // - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{feature}}_send_network_info_disabled_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is above expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" @operating_system:${{variant}} @network.client.reachability:*\").index(\"*\").rollup(\"count\").last(\"1d\") > 0"
  /// $monitor_threshold = 0.0
  /// $notify_no_data = false
  /// ```
  testWidgets('logger config - send network info disabled', (tester) async {
    await initializeDatadog(
      (config) => config.loggingConfiguration!.sendNetworkInfo = false,
    );

    sendRandomLog(tester);
  });

  // - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{feature}}_bundle_with_rum_enabled_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" @operating_system:${{variant}} @application_id:* @session_id:*\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  testWidgets('logger config - bundle with rum enabled', (tester) async {
    await initializeDatadog(
      (config) => config.loggingConfiguration!.bundleWithRum = true,
    );

    final viewKey = randomString();
    datadog.rum?.startView(viewKey);
    sendRandomLog(tester);
    datadog.rum?.stopView(viewKey);
  });

  // - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{feature}}_bundle_with_rum_disabled_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is above expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" @operating_system:${{variant}} @application_id:* @session_id:*\").index(\"*\").rollup(\"count\").last(\"1d\") > 0"
  /// $monitor_threshold = 0.0
  /// $notify_no_data = false
  /// ```
  testWidgets('logger config - bundle with rum disabled', (tester) async {
    await initializeDatadog(
      (config) => config.loggingConfiguration!.bundleWithRum = false,
    );

    final viewKey = randomString();
    datadog.rum?.startView(viewKey);
    sendRandomLog(tester);
    datadog.rum?.stopView(viewKey);
  });
}
