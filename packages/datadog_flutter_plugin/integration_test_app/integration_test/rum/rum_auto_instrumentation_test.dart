// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:convert';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_integration_test_app/auto_integration_scenarios/main.dart'
    as auto_app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../common.dart';

Future<void> performRumUserFlow(WidgetTester tester) async {
  // Give a bit of time for the images to be loaded
  await tester.pump(const Duration(seconds: 5));

  var topItem = find.text('Item 0');
  await tester.tap(topItem);
  await tester.pumpAndSettle();

  var readyText = find.text('All Done');
  await tester.waitFor(readyText, const Duration(seconds: 100), (e) => true);

  var nextButton = find.text('Next Page');
  await tester.tap(nextButton);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // This second test boots a different integration test app
  // (lib/auto_integration_scenario/main.dart) directly to the auto-instrumented
  // scenario with instrumentation enabled, then checks that we got the expected
  // calls.
  testWidgets('test auto instrumentation', (WidgetTester tester) async {
    startMockServer();

    const clientToken = bool.hasEnvironment('DD_CLIENT_TOKEN')
        ? String.fromEnvironment('DD_CLIENT_TOKEN')
        : null;
    const applicationId = bool.hasEnvironment('DD_APPLICATION_ID')
        ? String.fromEnvironment('DD_APPLICATION_ID')
        : null;

    auto_app.testingConfiguration = TestingConfiguration(
        customEndpoint: mockHttpServer!.endpoint,
        clientToken: clientToken,
        applicationId: applicationId,
        firstPartyHosts: ['localhost']);
    await auto_app.main();
    await tester.pumpAndSettle();

    await performRumUserFlow(tester);

    final requestLog = <RequestLog>[];
    final rumLog = <RumEventDecoder>[];
    final testRequests = <RequestLog>[];
    await mockHttpServer!.pollRequests(
      const Duration(seconds: 50),
      (requests) {
        requestLog.addAll(requests);
        for (var request in requests) {
          if (request.requestedUrl.contains('integration')) {
            testRequests.add(request);
          } else {
            request.data.split('\n').forEach((e) {
              var jsonValue = json.decode(e);
              if (jsonValue is Map<String, dynamic>) {
                rumLog.add(RumEventDecoder(jsonValue));
              }
            });
          }
        }
        return RumSessionDecoder.fromEvents(rumLog).visits.length >= 3;
      },
    );

    final session = RumSessionDecoder.fromEvents(rumLog);
    expect(session.visits.length, 3);

    final view1 = session.visits[0];
    expect(view1.name, '/');
    expect(view1.path, '/');

    final view2 = session.visits[1];
    expect(view2.name, 'rum_second_screen');
    expect(view2.path, 'rum_second_screen');

    // Check last view name
    final view3 = session.visits[2];
    expect(view3.name, 'RumAutoInstrumentationThirdScreen');
    expect(view3.path, 'RumAutoInstrumentationThirdScreen');
  });
}
