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
/// $feature = flutter_traces
/// $monitor_name_prefix = [RUM] [Flutter (${{variant:-global}})] Nightly - ${{test_description}}
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final random = Random();

  final datadog = DatadogSdk.instance;

  setUp(() async {
    await initializeDatadog();
    app.main();
  });

  tearDown(() async {
    await datadog.flushAndDeinitialize();
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_span_set_tag_boolean
  /// ```
  ///
  /// - data monitor: (it uses `flutter_${{variant}}_trace_span_set_tag_boolean` metric defined in "APM > Generate Metrics > Custom Span Metrics")
  /// ```apm(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of hits is below expected value"
  /// $monitor_query = "sum(last_1d):avg:flutter_${{variant}}_trace_span_set_tag_boolean.hits_with_proper_payload{*}.as_count() < 1"
  /// $monitor_threshold = 1
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,resource_name:traces_span_set_tag_boolean,service:com.datadog.flutter.nightly,@operating_system:${{variant}}} > 0.024"
  /// ```
  testWidgets('traces - span set tag boolean', (tester) async {
    final attributeValue = random.nextInt(100) < 50 ? true : false;

    final span = await startSpan('trace_span_set_tag_boolean');

    await measure('traces_span_set_tag_boolean', () async {
      await span.setTag('test_special_tag', attributeValue);
    });

    await span.finish();
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_span_set_tag_number
  /// ```
  ///
  /// - data monitor: (it uses `flutter_${{variant}}_trace_span_set_tag_number` metric defined in "APM > Generate Metrics > Custom Span Metrics")
  /// ```apm(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of hits is below expected value"
  /// $monitor_query = "sum(last_1d):avg:flutter_${{variant}}_trace_span_set_tag_number.hits_with_proper_payload{*}.as_count() < 1"
  /// $monitor_threshold = 1
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $feature = trace
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,resource_name:traces_span_set_tag_boolean,service:com.datadog.flutter.nightly,@operating_system:${{variant}}} > 0.024"
  /// ```
  testWidgets('traces - span set tag number', (tester) async {
    final attributeValue = random.nextInt(9) + 1;

    final span = await startSpan('trace_span_set_tag_number');

    await measure('traces_span_set_tag_number', () async {
      await span.setTag('test_special_tag', attributeValue);
    });

    await span.finish();
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_span_set_tag_string
  /// ```
  ///
  /// - data monitor: (it uses `flutter_${{variant}}_trace_span_set_tag_string` metric defined in "APM > Generate Metrics > Custom Span Metrics")
  /// ```apm(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of hits is below expected value"
  /// $monitor_query = "sum(last_1d):avg:flutter_${{variant}}_trace_span_set_tag_string.hits_with_proper_payload{*}.as_count() < 1"
  /// $monitor_threshold = 1
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = trace_span_set_operation_name_performance
  /// $monitor_name = "${{monitor_name_prefix}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,resource_name:traces_span_set_tag_string,service:com.datadog.flutter.nightly,@operating_system:${{variant}}} > 0.024"
  /// ```
  testWidgets('traces - span set tag string', (tester) async {
    final attributeValue = 'customTag' + randomString();

    final span = await startSpan('trace_span_set_tag_string');

    await measure('traces_span_set_tag_string', () async {
      await span.setTag('test_special_tag', attributeValue);
    });

    await span.finish();
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_span_set_baggage_item
  /// ```
  ///
  /// - data monitor: (it uses `flutter_${{variant}}_trace_span_set_baggage_item` metric defined in "APM > Generate Metrics > Custom Span Metrics")
  /// ```apm(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of hits is below expected value"
  /// $monitor_query = "sum(last_1d):avg:flutter_${{variant}}_trace_span_set_baggage_item.hits_with_proper_payload{*}.as_count() < 1"
  /// $monitor_threshold = 1
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,resource_name:traces_span_set_baggage_item,service:com.datadog.flutter.nightly,@operating_system:${{variant}}} > 0.024"
  /// ```
  testWidgets('traces - span set baggage item', (tester) async {
    final attributeValue = 'customBaggage' + randomString();

    final span = await startSpan('trace_span_set_baggage_item');

    await measure('traces_span_set_baggage_item', () async {
      await span.setBaggageItem('test_special_tag', attributeValue);
    });

    await span.finish();
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_span_performance
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_set_active_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,resource_name:traces_span_set_active,service:com.datadog.flutter.nightly,@operating_system:${{variant}}} > 0.024"
  /// ```
  testWidgets('traces - span performance', (tester) async {
    final span = await startSpan(randomString());

    await measure('traces_span_set_active', () async {
      await span.setActive();
    });

    await span.finish();
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_span_log
  /// ```
  ///
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: number of hits is below expected value"
  /// $monitor_query = "logs(\"service:com.datadog.flutter.nightly @test_method_name:\\\"${{test_description}}\\\" @operating_system:${{variant}} @test_special_string_attribute:customAttribute*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,resource_name:traces_span_log,service:com.datadog.flutter.nightly,@operating_system:${{variant}}} > 0.024"
  /// ```
  testWidgets('traces - span log', (tester) async {
    final span = await startSpan('trace_span_log_measured_span');
    await span.setActive();

    final fields = logAttributes(tester);
    fields['test_special_string_attribute'] =
        'customAttribute' + randomString();

    await measure('traces_span_log', () async {
      await span.log(fields);
    });

    await span.finish();
  });
}
