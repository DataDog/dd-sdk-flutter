// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_common_test/widget_tester_extensions.dart';
import 'package:datadog_dio_example/main.dart' as app;
import 'package:datadog_dio_example/scenario_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';

Future<void> performRumUserFlow(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));

  var topItem = find.text('Item 0');
  await tester.tap(topItem);
  await tester.pumpAndSettle();

  var fetchButton = find.text('Fetch Resources');
  await tester.tap(fetchButton);
  await tester.pumpAndSettle();

  var nextButton = find.widgetWithText(ElevatedButton, 'Next Page');
  await tester.waitFor(nextButton, const Duration(seconds: 100),
      (e) => (e.widget as ElevatedButton).enabled);
  await tester.tap(nextButton);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures request and response headers on RUM resource events',
      (WidgetTester tester) async {
    final sessionRecorder = await startMockServer();

    const clientToken = bool.hasEnvironment('DD_CLIENT_TOKEN')
        ? String.fromEnvironment('DD_CLIENT_TOKEN')
        : null;
    const applicationId = bool.hasEnvironment('DD_APPLICATION_ID')
        ? String.fromEnvironment('DD_APPLICATION_ID')
        : null;

    final scenarioConfig = RumAutoInstrumentationScenarioConfig(
      firstPartyHosts: [(sessionRecorder.sessionEndpoint)],
      firstPartyGetUrl: '${sessionRecorder.sessionEndpoint}/integration_get',
      firstPartyPostUrl: '${sessionRecorder.sessionEndpoint}/integration_post',
      firstPartyBadUrl: 'https://foo.bar',
      thirdPartyGetUrl: 'https://httpbingo.org/get',
      thirdPartyPostUrl: 'https://httpbingo.org/post',
      thirdPartyMissingUrl: 'https://httpbingo.org/status/404',
    );
    RumAutoInstrumentationScenarioConfig.instance = scenarioConfig;

    app.testingConfiguration = TestingConfiguration(
        customEndpoint: sessionRecorder.sessionEndpoint,
        clientToken: clientToken,
        applicationId: applicationId,
        firstPartyHosts: ['localhost']);
    await app.main();
    await tester.pumpAndSettle();

    await performRumUserFlow(tester);

    final rumLog = <RumEventDecoder>[];
    await sessionRecorder.pollSessionRequests(
      const Duration(seconds: 50),
      (requests) {
        for (var request in requests) {
          if (!request.requestedUrl.contains('integration')) {
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
    expect(session.visits.length, greaterThanOrEqualTo(3));

    final view2 = session.visits[1];

    final getEvent = view2.resourceEvents
        .firstWhereOrNull((e) => e.url == scenarioConfig.firstPartyGetUrl);
    expect(getEvent, isNotNull);
    expect(getEvent!.requestHeaders, isNotNull);
    expect(getEvent.requestHeaders!['x-datadog-origin'], 'rum');
    expect(getEvent.responseHeaders, isNotNull);
    expect(getEvent.responseHeaders!['content-type'], isNotNull);

    final postEvent = view2.resourceEvents
        .firstWhereOrNull((e) => e.url == scenarioConfig.firstPartyPostUrl);
    expect(postEvent, isNotNull);
    expect(postEvent!.requestHeaders, isNotNull);
    expect(postEvent.requestHeaders!['x-datadog-origin'], 'rum');
    expect(postEvent.responseHeaders, isNotNull);
    expect(postEvent.responseHeaders!['content-type'], isNotNull);
  }, skip: kIsWeb);
}
