// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_integration_test_app/integration_scenarios/scenario_runner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';
import 'rum_manual_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  kManualIsWeb = kIsWeb;

  // This is the same test as rum_manual_test.dart, but with the following
  // mappers:
  //  * viewMapper renames ThirdManualRumView to ThirdView
  //  * actionMapper changes 'Tapped Download' to 'Download'
  //  * actionMapper discards the 'Next Page' tap
  //  * actionMapper discards 'User Scrolling' events
  //  * resourceMapper and errorMapper rewite the urls to replace 'fake_url' with 'my_url'
  //  * longTask mapper discards all long tasks less than 200 ms
  //  * longTask mapper renames ThirdManualRumView to ThirdView
  testWidgets('test instrumentation with mappers', (WidgetTester tester) async {
    var serverRecorder = await openTestScenario(
      tester,
      menuTitle: 'Manual RUM Scenario',
      scenarioName: mappedInstrumentationScenarioName,
    );

    await performUserInteractions(tester);

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
    // In some cases, application_start doesn't get associated to the first view
    var actionCount = 1;
    var baseAction = 0;
    if (view1.actionEvents[0].actionType == 'application_start') {
      actionCount = 2;
      baseAction = 1;
    }
    expect(view1.actionEvents.length, actionCount);
    expect(view1.actionEvents[0 + baseAction].actionType, 'tap');
    expect(view1.actionEvents[0 + baseAction].actionName, 'Download');

    expect(view1.resourceEvents.length, 1);
    expect(view1.resourceEvents[0].url, 'https://my_url/resource/1');

    expect(view1.errorEvents.length, 1);
    expect(view1.errorEvents[0].resourceUrl, 'https://my_url/resource/2');

    final view2 = session.visits[1];
    // Scroll and 'Next Screen' tap are discarded
    expect(view2.actionEvents.length, 0);
    expect(view2.longTaskEvents.length, greaterThanOrEqualTo(1));
    for (var longTask in view2.longTaskEvents) {
      expect(
          longTask.duration,
          greaterThanOrEqualTo(
              const Duration(milliseconds: 200).inNanoseconds));
    }

    final view3 = session.visits[2];
    expect(view3.name, 'ThirdView');

    if (view3.longTaskEvents.isNotEmpty) {
      for (var event in view3.longTaskEvents) {
        expect(event.viewName, 'ThirdView');
      }
    }
  }, skip: true);
}
