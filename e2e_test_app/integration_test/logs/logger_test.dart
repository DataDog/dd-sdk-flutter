// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';
import 'dart:math';

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

  const specialStringAttributeKey = 'test_special_string_attribute';
  const specialIntAttributeKey = 'test_special_int_attribute';
  const specialBoolAttributeKey = 'test_special_bool_attribute';
  const specialDoubleAttributeKey = 'test_special_double_attribute';
  const specialTagKey = 'test_special_tag';
  final random = Random();

  setUp(() async {
    // TODO: Delete all SDK data
    await initializeDatadog();
    app.main();
  });

  tearDown(() async {
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
  /// ```apm(ios, android) IGNORE
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance - ${{test_description}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_log_debug_logs,service:${{service}}} > 0.024"
  /// ```
  testWidgets('logger - debug logs', (tester) async {
    await measure('flutter_log_debug_logs', () async {
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
  /// ```apm(ios, android) IGNORE
  /// $feature = logs
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance - ${{test_description}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_log_info_logs,service:${{service}}} > 0.024"
  /// ```
  testWidgets('logger - info logs', (tester) async {
    await measure('flutter_log_info_logs', () async {
      await datadog.logs?.info('fake info message', {
        'test_method_name': tester.testDescription,
        'operating_system': Platform.operatingSystem,
      });
    });
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_warn_log
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" status:warn @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $feature = logs
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance - ${{test_description}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_log_warn_logs,service:${{service}}} > 0.024"
  /// ```
  testWidgets('logger - warn logs', (tester) async {
    await measure('flutter_log_warn_logs', () async {
      await datadog.logs?.warn('fake warn message', {
        'test_method_name': tester.testDescription,
        'operating_system': Platform.operatingSystem,
      });
    });
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_error_log
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" status:error @operating_system:${{variant}}\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $feature = logs
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance - ${{test_description}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_log_error_logs,service:${{service}}} > 0.024"
  /// ```
  testWidgets('logger - error logs', (tester) async {
    await measure('flutter_log_error_logs', () async {
      await datadog.logs?.error('fake error message', {
        'test_method_name': tester.testDescription,
        'operating_system': Platform.operatingSystem,
      });
    });
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_add_string_attribute
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" @operating_system:${{variant}} @test_special_string_attribute:customAttribute*\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $feature = logs
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance - ${{test_description}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_log_add_string_attribute,service:${{service}}} > 0.024"
  /// ```
  testWidgets('logger - add string attribute', (tester) async {
    final attributeValue = 'customAttribute' + randomString();
    await measure('flutter_log_add_string_attribute', () async {
      await datadog.logs
          ?.addAttribute(specialStringAttributeKey, attributeValue);
    });

    await sendRandomLog(tester);
    await datadog.logs?.removeAttribute(specialStringAttributeKey);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_add_int_attribute
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" @operating_system:${{variant}} @test_special_int_attribute:>10\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $feature = logs
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance - ${{test_description}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_log_add_int_attribute,service:${{service}}} > 0.024"
  /// ```
  testWidgets('logger - add int attribute', (tester) async {
    final attributeValue = random.nextInt(10000) + 11;
    await measure('flutter_log_add_int_attribute', () async {
      await datadog.logs?.addAttribute(specialIntAttributeKey, attributeValue);
    });

    await sendRandomLog(tester);
    await datadog.logs?.removeAttribute(specialIntAttributeKey);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_add_double_attribute
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" @operating_system:${{variant}} @test_special_double_attribute:>10\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $feature = logs
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance - ${{test_description}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_log_add_double_attribute,service:${{service}}} > 0.024"
  /// ```
  testWidgets('logger - add double attribute', (tester) async {
    final attributeValue = random.nextDouble() * double.maxFinite;
    await measure('flutter_log_add_double_attribute', () async {
      await datadog.logs
          ?.addAttribute(specialDoubleAttributeKey, attributeValue);
    });

    await sendRandomLog(tester);
    await datadog.logs?.removeAttribute(specialDoubleAttributeKey);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_add_bool_attribute
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" @operating_system:${{variant}} @test_special_bool_attribute:(true OR false)\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $feature = logs
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance - ${{test_description}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_log_add_bool_attribute,service:${{service}}} > 0.024"
  /// ```
  testWidgets('logger - add bool attribute', (tester) async {
    final attributeValue = random.nextInt(100) < 50 ? true : false;
    await measure('flutter_log_add_bool_attribute', () async {
      await datadog.logs?.addAttribute(specialBoolAttributeKey, attributeValue);
    });

    await sendRandomLog(tester);
    await datadog.logs?.removeAttribute(specialBoolAttributeKey);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_add_tag_value
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" @operating_system:${{variant}} @test_special_tag:customTag*\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $feature = logs
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance - ${{test_description}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_log_add_tag_value,service:${{service}}} > 0.024"
  /// ```
  testWidgets('logger - add tag value', (tester) async {
    final tagValue = 'customTag' + randomString();
    await measure('flutter_log_add_tag_value', () async {
      await datadog.logs?.addTag(specialTagKey, tagValue);
    });

    await sendRandomLog(tester);
    await datadog.logs?.removeTagWithKey(specialTagKey);
  });

  /// ```global
  /// $monitor_prefix = ${{feature}}_add_tag
  /// ```
  ///
  /// - data monitor:
  /// ```logs(ios, android)
  /// $monitor_id = ${{monitor_prefix}}_data_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} - ${{test_description}}: number of logs is below expected value"
  /// $monitor_query = "logs(\"service:${{service}} @test_method_name:\\\"${{test_description}}\\\" @operating_system:${{variant}} @test_special_tag\").index(\"*\").rollup(\"count\").last(\"1d\") < 1"
  /// ```
  ///
  /// - performance monitor:
  /// ```apm(ios, android) IGNORE
  /// $feature = logs
  /// $monitor_id = ${{monitor_prefix}}_performance_${{variant}}
  /// $monitor_name = "${{monitor_name_prefix}} Performance - ${{test_description}}: has a high average execution time"
  /// $monitor_query = "avg(last_1d):p50:trace.perf_measure{env:instrumentation,@operating_system:${{variant}},resource_name:flutter_log_add_tag,service:${{service}}} > 0.024"
  /// ```
  testWidgets('logger - add tag', (tester) async {
    await measure('flutter_log_add_tag', () async {
      await datadog.logs?.addTag(specialTagKey);
    });

    await sendRandomLog(tester);
    await datadog.logs?.removeTag(specialTagKey);
  });
}
