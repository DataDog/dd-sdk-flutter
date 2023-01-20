// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_tracking_http_client_example/main.dart' as app;
import 'package:datadog_tracking_http_client_example/scenario_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> performRumUserFlow(WidgetTester tester) async {
  var scenario = find.text('http.Client Override');
  await tester.tap(scenario);
  await tester.pumpAndSettle();

  // Give a bit of time for the images to be loaded
  await tester.pump(const Duration(seconds: 5));

  var topItem = find.text('Item 0');
  await tester.tap(topItem);
  await tester.pumpAndSettle();

  var nextButton = find.text('Next Page');
  await tester.tap(nextButton);
  await tester.pumpAndSettle();
}

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final mockHttpServer = RecordingHttpServer();
  unawaited(mockHttpServer.start());
  final sessionRecorder = LocalRecordingServerClient(mockHttpServer);

  testWidgets('test auto instrumentation', (WidgetTester tester) async {
    await sessionRecorder.startNewSession();

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
      enableIoHttpTracking: false,
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

    final requestLog = <RequestLog>[];
    final rumLog = <RumEventDecoder>[];
    final testRequests = <RequestLog>[];
    await sessionRecorder.pollSessionRequests(
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
        return RumSessionDecoder.fromEvents(rumLog).visits.length >= 4;
      },
    );

    final session = RumSessionDecoder.fromEvents(rumLog);
    expect(session.visits.length, greaterThanOrEqualTo(3));

    final view1 = session.visits[1];
    // Images are not fetched with http.Client, so we don't expect them in
    // the final view
    expect(view1.viewEvents.last.view.resourceCount, 0);

    final view2 = session.visits[2];
    expect(view2.viewEvents.last.view.resourceCount, 4);
    expect(view2.viewEvents.last.view.errorCount, 1);

    // Check first party requests
    for (var testRequest in testRequests) {
      expect(testRequest.requestHeaders['x-datadog-sampling-priority']?.first,
          '1');
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
  });
}
