// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('test webview integrations', (tester) async {
    var serverRecorder = await openTestScenario(
      tester,
      menuTitle: 'WebView Scenario',
    );

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
        final session = RumSessionDecoder.fromEvents(rumLog,
            shouldDiscardApplicationLaunch: false);
        return session.visits.length >= 2;
      },
    );

    final session = RumSessionDecoder.fromEvents(rumLog,
        shouldDiscardApplicationLaunch: false);
    expect(session.visits.length, 2);

    // First view is applicaiton start, second view should be the webview
    final startView = session.visits[0];
    String expectedApplicationId =
        startView.viewEvents.first.rumEvent['application']['id'];
    String expectedSessionId =
        startView.viewEvents.first.rumEvent['session']['id'];

    final browserView = session.visits[1];

    for (var event in browserView.viewEvents) {
      expect(event.rumEvent['application']['id'], expectedApplicationId);
      expect(event.rumEvent['session']['id'], expectedSessionId);
      expect(event.service, 'shopist-web-ui');
      expect(event.rumEvent['source'], 'browser');
    }
    expect(browserView.resourceEvents.length, greaterThan(0));
    for (var resource in browserView.resourceEvents) {
      expect(resource.rumEvent['application']['id'], expectedApplicationId);
      expect(resource.rumEvent['session']['id'], expectedSessionId);
      expect(resource.service, 'shopist-web-ui');
      expect(resource.rumEvent['source'], 'browser');
    }
  });
}
