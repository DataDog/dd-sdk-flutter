// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:e2e_test_app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test_utils.dart';

/// ```global
/// $service = com.datadog.flutter.nightly
/// $feature = flutter_rum_consent
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

  Future<void> sendRandomRumEvent(WidgetTester tester) async {
    final viewKey = randomString();
    final viewName = randomString();

    final rumEvents = [
      () {
        datadog.rum!.startView(viewKey, viewName, e2eAttributes(tester));
        datadog.rum!.stopView(viewKey);
      },
      () {
        final resourceKey = randomString();
        datadog.rum!.startView(viewKey, viewName, e2eAttributes(tester));
        datadog.rum!.startResourceLoading(
            resourceKey, RumHttpMethod.get, randomString());
        datadog.rum!.stopResource(
            resourceKey, 200, RumResourceType.values.randomElement());
        datadog.rum!.stopView(viewKey);
      },
      () {
        datadog.rum!.startView(viewKey, viewName, e2eAttributes(tester));
        datadog.rum!.addErrorInfo(randomString(), RumErrorSource.custom);
        datadog.rum!.stopView(viewKey);
      },
      () {
        final actionName = randomString();
        datadog.rum!.startView(viewKey, viewName, e2eAttributes(tester));
        datadog.rum!.addUserAction(RumActionType.custom, actionName);
        datadog.rum!.stopView(viewKey);
      }
    ];

    final event = rumEvents.randomElement();
    event();
  }

  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_prefix = ${{feature}}_granted
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of views is below expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @type:view @context.operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  testWidgets('rum consent - granted', (tester) async {
    await initializeDatadog();

    await sendRandomRumEvent(tester);
  });

  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_prefix = ${{feature}}_not_granted
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of views is above expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @type:view @context.operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") > 0"
  /// $monitor_threshold = 0.0
  /// ```
  testWidgets('rum consent - not granted', (tester) async {
    await initializeDatadog(
        (config) => config.trackingConsent = TrackingConsent.notGranted);

    await sendRandomRumEvent(tester);
  });

  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_prefix = ${{feature}}_pending
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of views is above expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @type:view @context.operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") > 0"
  /// $monitor_threshold = 0.0
  /// ```
  testWidgets('rum consent - pending', (tester) async {
    await initializeDatadog(
        (config) => config.trackingConsent = TrackingConsent.pending);

    await sendRandomRumEvent(tester);
  });

  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_prefix = ${{feature}}_pending_to_granted
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of views is below expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @type:view @context.operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  testWidgets('rum consent - pending to granted', (tester) async {
    await initializeDatadog(
        (config) => config.trackingConsent = TrackingConsent.pending);

    await sendRandomRumEvent(tester);

    datadog.setTrackingConsent(TrackingConsent.granted);
  });
}
