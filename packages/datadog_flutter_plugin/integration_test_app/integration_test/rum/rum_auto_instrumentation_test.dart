// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:convert';

import 'package:datadog_integration_test_app/auto_integration_scenarios/main.dart'
    as auto_app;
import 'package:datadog_integration_test_app/auto_integration_scenarios/scenario_config.dart';
import 'package:datadog_integration_test_app/helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../common.dart';
import '../tools/mock_http_sever.dart';
import 'rum_decoder.dart';

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

    final scenarioConfig = RumAutoInstrumentationScenarioConfig(
      firstPartyHosts: ['localhost:${MockHttpServer.bindingPort}'],
      firstPartyGetUrl: '${mockHttpServer!.endpoint}/integration_get',
      firstPartyPostUrl: '${mockHttpServer!.endpoint}/integration_post',
      firstPartyBadUrl: 'https://foo.bar',
      thirdPartyGetUrl: 'https://httpbingo.org/get',
      thirdPartyPostUrl: 'https://httpbingo.org/post',
    );
    RumAutoInstrumentationScenarioConfig.instance = scenarioConfig;

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
    expect(view1.viewEvents.last.view.resourceCount, 2);
    expect(view1.resourceEvents[0].url, 'https://placekitten.com/300/300');
    // placekitten.com doesn't set contentType headers properly, so don't test it
    expect(view1.resourceEvents[1].url,
        'https://imgix.datadoghq.com/img/about/presskit/kit/press_kit.png');
    // Allow this to fail since we don't have as much control over them
    if (view1.resourceEvents[1].statusCode == 200) {
      expect(view1.resourceEvents[1].resourceType, 'image');
    }

    final view2 = session.visits[1];
    expect(view2.name, 'rum_second_screen');
    expect(view2.path, 'rum_second_screen');
    expect(view2.viewEvents.last.view.resourceCount, 4);
    expect(view2.viewEvents.last.view.errorCount, 1);

    // Check first party requests
    for (var testRequest in testRequests) {
      expect(testRequest.requestHeaders['x-datadog-sampling-priority']?.first,
          '1');
      expect(testRequest.requestHeaders['x-datadog-sampled']?.first, '1');
      expect(testRequest.requestHeaders['x-datadog-origin']?.first, 'rum');
    }

    final getEvent = view2.resourceEvents[0];
    final getTraceId =
        testRequests[0].requestHeaders['x-datadog-trace-id']?.first;
    final getSpanId =
        testRequests[0].requestHeaders['x-datadog-parent-id']?.first;
    expect(getEvent.url, scenarioConfig.firstPartyGetUrl);
    expect(getEvent.statusCode, 200);
    expect(getEvent.method, 'GET');
    expect(getEvent.duration, greaterThan(0));
    expect(getEvent.dd.traceId, getTraceId!);
    expect(getEvent.dd.spanId, getSpanId!);

    final postTraceId =
        testRequests[1].requestHeaders['x-datadog-trace-id']?.first;
    final postSpanId =
        testRequests[1].requestHeaders['x-datadog-parent-id']?.first;
    final postEvent = view2.resourceEvents[1];
    expect(postEvent.url, scenarioConfig.firstPartyPostUrl);
    expect(postEvent.statusCode, 200);
    expect(postEvent.method, 'POST');
    expect(postEvent.duration, greaterThan(0));
    expect(postEvent.dd.traceId, postTraceId!);
    expect(postEvent.dd.spanId, postSpanId!);

    // Third party requests
    expect(view2.errorEvents[0].resourceUrl, scenarioConfig.firstPartyBadUrl);
    expect(view2.errorEvents[0].resourceMethod, 'GET');

    expect(view2.resourceEvents[2].url, scenarioConfig.thirdPartyGetUrl);
    expect(view2.resourceEvents[2].method, 'GET');
    expect(view2.resourceEvents[2].duration, greaterThan(0));
    expect(view2.resourceEvents[2].dd.traceId, isNull);
    expect(view2.resourceEvents[2].dd.spanId, isNull);

    expect(view2.resourceEvents[3].url, scenarioConfig.thirdPartyPostUrl);
    expect(view2.resourceEvents[3].method, 'POST');
    expect(view2.resourceEvents[3].duration, greaterThan(0));
    expect(view2.resourceEvents[3].dd.traceId, isNull);
    expect(view2.resourceEvents[3].dd.spanId, isNull);

    // Check last view name
    final view3 = session.visits[2];
    expect(view3.name, 'RumAutoInstrumentationThirdScreen');
    expect(view3.path, 'RumAutoInstrumentationThirdScreen');
  });
}
