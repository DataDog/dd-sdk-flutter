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
import 'tracing_id_helpers.dart';

Future<void> performRumUserFlow(WidgetTester tester) async {
  // Give a bit of time for the images to be loaded
  await tester.pump(const Duration(seconds: 5));

  var topItem = find.text('Item 0');
  await tester.tap(topItem);
  await tester.pumpAndSettle();

  var fetchButton = find.text('Fetch Resources');
  await tester.tap(fetchButton);
  await tester.pumpAndSettle();

  var nextButton = find.widgetWithText(ElevatedButton, 'Next Page');
  await tester.waitFor(
    nextButton,
    const Duration(seconds: 100),
    (e) => (e.widget as ElevatedButton).enabled,
  );
  await tester.tap(nextButton);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('test auto instrumentation', (WidgetTester tester) async {
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
      firstPartyHosts: ['localhost'],
    );
    await app.main();
    await tester.pumpAndSettle();

    await performRumUserFlow(tester);

    final requestLog = <RequestLog>[];
    final rumLog = <RumEventDecoder>[];
    final testRequests = <RequestLog>[];
    await sessionRecorder.pollSessionRequests(const Duration(seconds: 50), (
      requests,
    ) {
      requestLog.addAll(requests);
      for (var request in requests) {
        if (request.requestedUrl.contains('integration')) {
          if (!request.requestHeaders.containsKey(
            'access-control-request-method',
          )) {
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
      return RumSessionDecoder.fromEvents(rumLog).visits.length >= 3;
    });

    final session = RumSessionDecoder.fromEvents(rumLog);
    expect(session.visits.length, greaterThanOrEqualTo(3));

    final view1 = session.visits[0];

    // Dio doesn't load the images, so this should always be zero
    expect(
      view1.viewEvents.last.view.resourceCount,
      view1.resourceEvents.length,
    );

    final view2 = session.visits[1];
    expect(
      view2.viewEvents.last.view.resourceCount,
      view2.resourceEvents.length,
    );
    if (!kIsWeb) {
      // Web doesn't report the failed resource as an error
      expect(view2.viewEvents.last.view.errorCount, 1);
    }

    // Check first party requests
    for (var testRequest in testRequests) {
      expect(
        testRequest.requestHeaders['x-datadog-sampling-priority']?.first,
        '1',
      );
      expect(testRequest.requestHeaders['x-datadog-origin']?.first, 'rum');

      final baggageHeader = testRequest.requestHeaders['baggage']?.first;
      final baggageValues = baggageHeader?.split(',');
      expect(
        baggageValues?.firstWhereOrNull((e) => e.contains('session.id')),
        isNotNull,
      );
      expect(baggageValues, contains('user.id=integration_test_user'));
      expect(baggageValues, contains('account.id=integration_test_account'));
    }

    final getEvent = view2.resourceEvents.firstWhereOrNull(
      (e) => e.url == scenarioConfig.firstPartyGetUrl,
    );
    expect(getEvent, isNotNull);
    final getRequest = testRequests.firstWhere(
      (e) => e.requestedUrl == scenarioConfig.firstPartyGetUrl,
    );
    final getTraceId = extractDatadogTraceId(getRequest.requestHeaders);
    final getSpanId = getRequest.requestHeaders['x-datadog-parent-id']?.first;
    expect(getEvent!.url, scenarioConfig.firstPartyGetUrl);
    expect(getEvent.statusCode, 200);
    expect(getEvent.method, 'GET');
    expect(getEvent.duration, greaterThan(0));
    expect(getEvent.dd.traceId, getTraceId?.toRadixString(kIsWeb ? 10 : 16));
    expect(getEvent.dd.spanId, getSpanId!);

    final postEvent = view2.resourceEvents.firstWhereOrNull(
      (e) => e.url == scenarioConfig.firstPartyPostUrl,
    );
    expect(postEvent, isNotNull);
    final postRequest = testRequests.firstWhere(
      (e) => e.requestedUrl == scenarioConfig.firstPartyPostUrl,
    );
    final postTraceId = extractDatadogTraceId(postRequest.requestHeaders);
    final postSpanId = postRequest.requestHeaders['x-datadog-parent-id']?.first;
    expect(postEvent!.url, scenarioConfig.firstPartyPostUrl);
    expect(postEvent.statusCode, 200);
    expect(postEvent.method, 'POST');
    expect(postEvent.duration, greaterThan(0));
    expect(postEvent.dd.traceId, postTraceId?.toRadixString(kIsWeb ? 10 : 16));
    expect(postEvent.dd.spanId, postSpanId!);

    // Third party requests
    if (!kIsWeb) {
      expect(
        view2.errorEvents[0].resourceUrl,
        startsWith(scenarioConfig.firstPartyBadUrl),
      );
      expect(view2.errorEvents[0].resourceMethod, 'GET');
    } else {
      final errorResourceEvent = view2.resourceEvents.firstWhereOrNull(
        (e) => e.url.contains(scenarioConfig.firstPartyBadUrl),
      );
      expect(
        errorResourceEvent!.url,
        startsWith(scenarioConfig.firstPartyBadUrl),
      );
      expect(errorResourceEvent.method, 'GET');
    }

    final firstThirdPartyResource = view2.resourceEvents.firstWhereOrNull(
      (e) => e.url.contains(scenarioConfig.thirdPartyGetUrl),
    );
    expect(firstThirdPartyResource, isNotNull);
    expect(
      firstThirdPartyResource!.url,
      startsWith(scenarioConfig.thirdPartyGetUrl),
    );
    expect(firstThirdPartyResource.method, 'GET');
    expect(firstThirdPartyResource.duration, greaterThan(0));
    expect(firstThirdPartyResource.dd.traceId, isNull);
    expect(firstThirdPartyResource.dd.spanId, isNull);

    final secondThirdPartyResource = view2.resourceEvents.firstWhereOrNull(
      (e) => e.url.contains(scenarioConfig.thirdPartyPostUrl),
    );
    expect(secondThirdPartyResource, isNotNull);
    expect(
      secondThirdPartyResource!.url,
      startsWith(scenarioConfig.thirdPartyPostUrl),
    );
    expect(secondThirdPartyResource.method, 'POST');
    expect(secondThirdPartyResource.duration, greaterThan(0));
    expect(secondThirdPartyResource.dd.traceId, isNull);
    expect(secondThirdPartyResource.dd.spanId, isNull);

    final missingThirdPartyResource = view2.resourceEvents.firstWhereOrNull(
      (e) => e.url.contains(scenarioConfig.thirdPartyMissingUrl),
    );
    expect(missingThirdPartyResource, isNotNull);
    expect(
      missingThirdPartyResource!.url,
      startsWith(scenarioConfig.thirdPartyMissingUrl),
    );
    expect(missingThirdPartyResource.method, 'GET');
    expect(missingThirdPartyResource.duration, greaterThan(0));
    expect(missingThirdPartyResource.dd.traceId, isNull);
    expect(missingThirdPartyResource.dd.spanId, isNull);
  });
}
