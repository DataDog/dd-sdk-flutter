// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:convert';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';
import 'rum_auto_instrumentation_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // This first test boots the normal integration test app and opens the auto
  // instrumentation scenario. However, since nothing in that section of the app
  // is instrumented, we expect nothing to be sent back to Datadog
  testWidgets('test auto instrumentation with no results',
      (WidgetTester tester) async {
    var recordedSession = await openTestScenario(
      tester,
      menuTitle: 'Auto RUM Scenario',
    );

    await performRumUserFlow(tester);
    var requestLog = <RequestLog>[];
    var rumLog = <RumEventDecoder>[];
    await recordedSession.pollSessionRequests(
      const Duration(seconds: 30),
      (requests) {
        requestLog.addAll(requests);
        requests.map((e) => e.data.split('\n')).expand((e) => e).forEach((e) {
          Map<String, Object?> jsonValue = json.decode(e);
          final rumEvent = RumEventDecoder.fromJson(jsonValue);
          if (rumEvent != null) {
            rumLog.add(rumEvent);
          }
        });
        return false;
      },
    );
    // Decode this session. This removes events that came from
    // the ApplicationLaunchView (which can happen if the emulator is running slow)
    var session = RumSessionDecoder.fromEvents(rumLog);

    if (session.visits.isNotEmpty) {
      // ignore: avoid_print
      print('Got a RUM log!? (actually ${rumLog.length})');
      for (var log in rumLog) {
        // ignore: avoid_print
        print('Log: { event: ${log.eventType}, view: ${log.view.name}');
      }
    }
    expect(session.visits.isEmpty, isTrue);
  });
}
