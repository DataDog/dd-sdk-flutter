// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:e2e_test_app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test_utils.dart';

/// ```global
/// $service = com.datadog.flutter.nightly
/// $feature = flutter_logs_consent
/// $monitor_name_prefix = [RUM] [Flutter (${{variant:-global}})] Nightly
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // TODO: Delete all SDK data
    app.main();
  });

  tearDown(() async {
    await DatadogSdk.instance.flushAndDeinitialize();
  });

  // Convenience field
  final datadog = DatadogSdk.instance;

  /// ```global
  /// $monitor_prefix = ${{feature}}_granted
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" status:debug @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  testWidgets('logger consent - granted', (tester) async {
    await initializeDatadog();

    await sendRandomLog(tester);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_not_granted
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is above expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" status:debug @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") > 0"
  /// $monitor_threshold = 0.0
  /// $notify_no_data = false
  /// ```
  testWidgets('logger consent - not granted', (tester) async {
    await initializeDatadog(
      (config) => config.trackingConsent = TrackingConsent.notGranted,
    );

    await sendRandomLog(tester);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_pending
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is above expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" status:debug @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") > 0"
  /// $monitor_threshold = 0.0
  /// $notify_no_data = false
  /// ```
  testWidgets('logger consent - pending', (tester) async {
    await initializeDatadog(
      (config) => config.trackingConsent = TrackingConsent.pending,
    );

    await sendRandomLog(tester);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_granted_to_not_granted
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is above expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" status:debug @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") > 0"
  /// $monitor_threshold = 0.0
  /// $notify_no_data = false
  /// ```
  testWidgets('logger consent - granted to not granted', (tester) async {
    await initializeDatadog(
      (config) => config.trackingConsent = TrackingConsent.granted,
    );
    await measure('flutter_log_consent_set_tracking_consent', () async {
      await datadog.setTrackingConsent(TrackingConsent.notGranted);
    });

    await sendRandomLog(tester);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_granted_to_pending
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is above expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" status:debug @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") > 0"
  /// $monitor_threshold = 0.0
  /// $notify_no_data = false
  /// ```
  testWidgets('logger consent - granted to pending', (tester) async {
    await initializeDatadog(
      (config) => config.trackingConsent = TrackingConsent.granted,
    );
    await measure('flutter_log_consent_set_tracking_consent', () async {
      await datadog.setTrackingConsent(TrackingConsent.pending);
    });

    await sendRandomLog(tester);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_not_granted_to_granted
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" status:debug @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  testWidgets('logger consent - not granted to granted', (tester) async {
    await initializeDatadog(
      (config) => config.trackingConsent = TrackingConsent.notGranted,
    );
    await measure('flutter_log_consent_set_tracking_consent', () async {
      await datadog.setTrackingConsent(TrackingConsent.granted);
    });

    await sendRandomLog(tester);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_not_granted_to_pending
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is above expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" status:debug @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") > 0"
  /// $monitor_threshold = 0.0
  /// $notify_no_data = false
  /// ```
  testWidgets('logger consent - not granted to pending', (tester) async {
    await initializeDatadog(
      (config) => config.trackingConsent = TrackingConsent.notGranted,
    );
    await measure('flutter_log_consent_set_tracking_consent', () async {
      await datadog.setTrackingConsent(TrackingConsent.pending);
    });

    await sendRandomLog(tester);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_pending_to_granted
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" status:debug @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  testWidgets('logger consent - pending to granted', (tester) async {
    await initializeDatadog(
      (config) => config.trackingConsent = TrackingConsent.pending,
    );
    await measure('flutter_log_consent_set_tracking_consent', () async {
      await datadog.setTrackingConsent(TrackingConsent.granted);
    });

    await sendRandomLog(tester);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_pending_to_not_granted
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is above expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" status:debug @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") > 0"
  /// $monitor_threshold = 0.0
  /// $notify_no_data = false
  /// ```
  testWidgets('logger consent - pending to not granted', (tester) async {
    await initializeDatadog(
      (config) => config.trackingConsent = TrackingConsent.pending,
    );
    await measure('flutter_log_consent_set_tracking_consent', () async {
      await datadog.setTrackingConsent(TrackingConsent.notGranted);
    });

    await sendRandomLog(tester);
  });
}
