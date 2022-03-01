// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:math';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:e2e_test_app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test_utils.dart';

/// ```global
/// $service = com.datadog.flutter.nightly
/// $feature = flutter_rum
/// $monitor_name_prefix = [RUM] [Flutter (${{variant:-global}})] Nightly - ${{test_description}}
/// ```
void main() {
  const actionInactivityThreshold = Duration(milliseconds: 100);

  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final random = Random();
  final datadog = DatadogSdk.instance;

  setUp(() async {
    // TODO: Delete all SDK data
    await initializeDatadog();
    app.main();
  });

  tearDown(() async {
    await DatadogSdk.instance.flushAndDeinitialize();
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_start_view
  /// ```
  ///
  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of views is below expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @type.view @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance - ${{test_description}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_rum_start_view,service:${{service}}} > 0.024"
  /// ```
  testWidgets('rum - start view', (tester) async {
    final viewKey = randomString();
    await measure('flutter_rum_start_view', () async {
      await datadog.rum!.startView(
        viewKey,
        randomString(),
        e2eAttributes(tester),
      );
    });

    await datadog.rum!.stopView(viewKey);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_add_timing
  /// ```
  ///
  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: custom timing value is high than expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @type.view @operating_system:${{variant}}\").rollup(\"avg\", \"@view.custom_timings.time_event\").last(\"1d\") > 700000000"
  /// $monitor_threshold = 700000000
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_rum_add_timing,service:${{service}}} > 0.024"
  /// ```
  testWidgets('rum - add timing', (tester) async {
    final viewKey = randomString();
    final delay = random.nextInt(500) + 200;
    await datadog.rum!.startView(
      viewKey,
      randomString(),
      e2eAttributes(tester),
    );

    await Future.delayed(Duration(seconds: delay));
    await measure('flutter_rum_add_timing', () async {
      await datadog.rum!.addTiming('time_event');
    });

    await datadog.rum!.stopView(viewKey);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_simple_action
  /// ```
  ///
  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of views is below expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @operating_system:${{variant}}\").rollup(\"count\").by(\"@type\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_rum_simple_action,service:${{service}}} > 0.024"
  /// ```
  testWidgets('rum - simple action', (tester) async {
    final viewKey = randomString();
    await datadog.rum!.startView(
      viewKey,
      randomString(),
      e2eAttributes(tester),
    );

    await measure('flutter_rum_simple_action', () async {
      await datadog.rum!.addUserAction(RumUserActionType.tap, randomString());
    });

    await datadog.rum!.stopView(viewKey);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_long_action
  /// ```
  ///
  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of views is below expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @operating_system:${{variant}}\").rollup(\"count\").by(\"@type\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitors:
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_start_user_action,service:${{service}}} > 0.024"
  /// ```
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_stop_user_action,service:${{service}}} > 0.024"
  /// ```
  testWidgets('rum - long action', (tester) async {
    final viewKey = randomString();
    await datadog.rum!.startView(
      viewKey,
      randomString(),
      e2eAttributes(tester),
    );

    final actionName = randomString();
    await measure('flutter_start_user_action', () async {
      await datadog.rum!.startUserAction(
        RumUserActionType.scroll,
        actionName,
        e2eAttributes(tester),
      );
    });

    await measure('flutter_stop_user_action', () async {
      await datadog.rum!.stopUserAction(RumUserActionType.scroll, actionName);
    });

    await datadog.rum!.stopView(viewKey);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_resource_loading
  /// ```
  ///
  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of views is below expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @type:resource @operating_system:${{variant}}\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitors:
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_start_resource,service:${{service}}} > 0.024"
  /// ```
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_stop_resource,service:${{service}}} > 0.024"
  /// ```
  testWidgets('rum - resource loading', (tester) async {
    final viewKey = randomString();
    await datadog.rum!.startView(
      viewKey,
      randomString(),
      e2eAttributes(tester),
    );

    final resourceKey = randomString();
    await measure('flutter_start_resource', () async {
      await datadog.rum!.startResourceLoading(
        resourceKey,
        RumHttpMethod.get,
        randomString(),
        e2eAttributes(tester),
      );
    });

    await measure('flutter_stop_resource', () async {
      await datadog.rum!.stopResourceLoading(
          resourceKey, 200, RumResourceType.values.randomElement());
    });

    await datadog.rum!.stopView(viewKey);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_resource_loading_with_error
  /// ```
  ///
  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of views is below expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @type:error @operating_system:${{variant}}\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitors:
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_stop_resource_with_error,service:${{service}}} > 0.024"
  /// ```
  testWidgets('rum - resource loading with error', (tester) async {
    final viewKey = randomString();
    await datadog.rum!.startView(
      viewKey,
      randomString(),
      e2eAttributes(tester),
    );

    final resourceKey = randomString();
    await datadog.rum!.startResourceLoading(
      resourceKey,
      RumHttpMethod.get,
      randomString(),
      e2eAttributes(tester),
    );

    await measure('flutter_stop_resource_with_error', () async {
      await datadog.rum!.stopResourceLoadingWithErrorInfo(
          resourceKey, randomString(), e2eAttributes(tester));
    });

    await datadog.rum!.stopView(viewKey);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_add_error
  /// ```
  ///
  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of views is below expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @type:error @operating_system:${{variant}}\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitors:
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_add_error,service:${{service}}} > 0.024"
  /// ```
  testWidgets('rum - add error', (tester) async {
    final viewKey = randomString();
    await datadog.rum!.startView(
      viewKey,
      randomString(),
      e2eAttributes(tester),
    );

    await measure('flutter_add_error', () async {
      await datadog.rum!
          .addErrorInfo(randomString(), RumErrorSource.values.randomElement());
    });

    await datadog.rum!.stopView(viewKey);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_add_error
  /// ```
  ///
  /// - data monitor:
  /// ```rum(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of views is below expected value"
  /// $monitor_query = "rum(\"service:${{service}} @context.test_method_name:\\\"${{test_description}}\\\" @type:error @operating_system:${{variant}}\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitors:
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_add_error_with_stacktrace,service:${{service}}} > 0.024"
  /// ```
  testWidgets('rum - add error with stacktrace', (tester) async {
    final viewKey = randomString();
    await datadog.rum!.startView(
      viewKey,
      randomString(),
      e2eAttributes(tester),
    );

    final stackTrace = StackTrace.current;
    await measure('flutter_add_error_with_stacktrace', () async {
      await datadog.rum!.addErrorInfo(
          randomString(), RumErrorSource.values.randomElement(),
          stackTrace: stackTrace);
    });

    await datadog.rum!.stopView(viewKey);
  });
}
