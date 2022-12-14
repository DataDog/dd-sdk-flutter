// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_integration_test_app/auto_integration_scenarios/scenario_runner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';
import 'rum_auto_instrumentation_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  kManualIsWeb = kIsWeb;

  testWidgets('test telemetry scenario', (WidgetTester tester) async {
    var serverRecorder = await openTestScenario(tester,
        scenarioName: autoInstrumentationScenarioName);

    await performRumUserFlow(tester);
    var endTime = DateTime.now().add(const Duration(seconds: 6));
    // Wait for telemetry
    while (DateTime.now().isBefore(endTime)) {
      await tester.pumpAndSettle();
    }

    final requestLog = <RequestLog>[];
    final telemetryLog = <RumEventDecoder>[];
    await serverRecorder.pollSessionRequests(
      const Duration(seconds: 50),
      (requests) {
        requestLog.addAll(requests);
        for (var request in requests) {
          request.data.split('\n').forEach((e) {
            dynamic jsonValue = json.decode(e);
            if (jsonValue is Map<String, dynamic>) {
              var rumEvent = RumEventDecoder(jsonValue);
              if (rumEvent.eventType == 'telemetry') {
                telemetryLog.add(rumEvent);
              }
            }
          });
        }
        return telemetryLog
            .where((element) => element.telemetryConfiguration != null)
            .isNotEmpty;
      },
    );

    var telemetryEvent = telemetryLog
        .where((element) => element.telemetryConfiguration != null)
        .firstOrNull;
    expect(telemetryEvent, isNotNull);
    if (telemetryEvent != null) {
      final config = telemetryEvent.telemetryConfiguration!;
      expect(config['track_views_manually'], false);
      expect(config['track_interactions'], false);
      expect(config['track_errors'], true);
      expect(config['track_network_requests'], false);
      expect(config['track_native_views'], false);
      expect(config['track_cross_platform_long_tasks'], true);
      expect(config['track_flutter_performance'], true);
    }
  });
}
