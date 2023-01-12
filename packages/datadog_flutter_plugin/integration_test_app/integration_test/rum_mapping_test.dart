// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'dart:convert';

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

  // This is the same test as rum_auto_instrumentation_test.dart, but with the following
  // mappers:
  //  * viewMapper renames RumAutoInstrumentationThirdScreen to rum_third_screen
  //  * actionMapper removes 'InkWell' from targets
  //  * actionMapper discards the 'Next Page' tap
  testWidgets('test auto instrumentation with mappers',
      (WidgetTester tester) async {
    var serverRecorder = await openTestScenario(
      tester,
      scenarioName: mappedAutoInstrumentationScenarioName,
    );

    await performRumUserFlow(tester);

    final requestLog = <RequestLog>[];
    final rumLog = <RumEventDecoder>[];
    await serverRecorder.pollSessionRequests(
      const Duration(seconds: 50),
      (requests) {
        requestLog.addAll(requests);
        for (var request in requests) {
          request.data.split('\n').forEach((e) {
            dynamic jsonValue = json.decode(e);
            if (jsonValue is Map<String, dynamic>) {
              rumLog.add(RumEventDecoder(jsonValue));
            }
          });
        }
        return RumSessionDecoder.fromEvents(rumLog).visits.length >= 3;
      },
    );

    final session = RumSessionDecoder.fromEvents(rumLog);
    expect(session.visits.length, 3);

    final view1 = session.visits[0];
    expect(view1.name, '/');
    if (!kIsWeb) {
      // Path is the actual browser path in web
      expect(view1.path, '/');

      // Web doesn't support performance metrics
      expect(view1.viewEvents.last.flutterBuildTime, isNotNull);
      expect(view1.viewEvents.last.flutterRasterTime, isNotNull);

      // Web doesn't support action tracking from Flutter
      var actionEvent = view1.actionEvents.last;
      expect(actionEvent.actionType, 'tap');
      expect(actionEvent.actionName, 'Item 0');
    }

    final view2 = session.visits[1];
    expect(view2.name, 'rum_second_screen');
    if (!kIsWeb) {
      // Path is the actual browser path in web
      expect(view2.path, 'rum_second_screen');

      // Web doesn't support performance metrics
      expect(view2.viewEvents.last.flutterBuildTime, isNotNull);
      expect(view2.viewEvents.last.flutterRasterTime, isNotNull);

      // Web doesn't support action tracking from Flutter
      expect(view2.actionEvents.length, 0);
    }

    // Check last view name
    final view3 = session.visits[2];
    expect(view3.name, 'rum_third_screen');
    if (!kIsWeb) {
      // Path is the actual browser path in web
      expect(view3.path, 'RumAutoInstrumentationThirdScreen');
    }
  });
}
