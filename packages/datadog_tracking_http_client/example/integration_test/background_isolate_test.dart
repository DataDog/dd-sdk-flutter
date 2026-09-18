// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_common_test/widget_tester_extensions.dart';
import 'package:datadog_tracking_http_client_example/main.dart' as app;
import 'package:datadog_tracking_http_client_example/scenario_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';
import 'tracing_id_helpers.dart';

Future<void> performRumUserFlow(WidgetTester tester) async {
  var scenario = find.text('Background Isolate Fetch');
  await tester.tap(scenario);
  await tester.pumpAndSettle();

  // Give a bit of time for the images to be loaded
  await tester.pump(const Duration(seconds: 5));

  var topItem = find.text('Send Traceable Log');
  await tester.tap(topItem);
  await tester.pumpAndSettle();

  var doneText = find.text('Done');
  await tester.waitFor(doneText, const Duration(seconds: 10), (e) => true);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('test background isolate tracking', (WidgetTester tester) async {
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
      firstPartyBadUrl: 'https://foo.bar/',
      thirdPartyGetUrl: 'https://httpbingo.org/get/',
      thirdPartyPostUrl: 'https://httpbingo.org/post/',
      enableIoHttpTracking: true,
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
            if (!request.requestHeaders
                .containsKey('access-control-request-method')) {
              testRequests.add(request);
            }
          } else {
            request.data.split('\n').forEach((e) {
              var jsonValue = json.decode(e);
              if (jsonValue is Map<String, dynamic>) {
                rumLog.add(RumEventDecoder(jsonValue));
              }
            });
          }
        }
        final rumSession = RumSessionDecoder.fromEvents(rumLog);
        return rumSession.visits.length > 1 &&
            rumSession.visits[1].resourceEvents.length >= 2;
      },
    );

    final session = RumSessionDecoder.fromEvents(rumLog);

    final view1 = session.visits[1];
    expect(view1.viewEvents.last.view.resourceCount, 2);

    // Check first party requests
    for (var testRequest in testRequests) {
      expect(testRequest.requestHeaders['x-datadog-sampling-priority']?.first,
          '1');
      expect(testRequest.requestHeaders['x-datadog-origin']?.first, 'rum');

      final baggageHeader = testRequest.requestHeaders['baggage']?.first;
      final baggageValues = baggageHeader?.split(',');
      expect(baggageValues?.firstWhereOrNull((e) => e.contains('session.id')),
          isNotNull);
      expect(baggageValues, contains('user.id=integration_test_user'));
      expect(baggageValues, contains('account.id=integration_test_account'));
    }

    final getEvent = view1.resourceEvents[0];
    final getTraceId = extractDatadogTraceId(testRequests[0].requestHeaders);
    final getSpanId =
        testRequests[0].requestHeaders['x-datadog-parent-id']?.first;
    expect(getEvent.url, scenarioConfig.firstPartyGetUrl);
    expect(getEvent.statusCode, 200);
    expect(getEvent.method, 'GET');
    expect(getEvent.duration, greaterThan(0));
    expect(getEvent.dd.traceId, getTraceId?.toRadixString(16));
    expect(getEvent.dd.spanId, getSpanId!);

    final postTraceId = extractDatadogTraceId(testRequests[1].requestHeaders);
    final postSpanId =
        testRequests[1].requestHeaders['x-datadog-parent-id']?.first;
    final postEvent = view1.resourceEvents[1];
    expect(postEvent.url, scenarioConfig.firstPartyPostUrl);
    expect(postEvent.statusCode, 200);
    expect(postEvent.method, 'POST');
    expect(postEvent.duration, greaterThan(0));
    expect(postEvent.dd.traceId, postTraceId?.toRadixString(16));
    expect(postEvent.dd.spanId, postSpanId!);
  }, skip: kIsWeb);
}
