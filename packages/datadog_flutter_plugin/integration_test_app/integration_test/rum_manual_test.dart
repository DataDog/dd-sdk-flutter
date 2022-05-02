// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:convert';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('test rum scenario', (WidgetTester tester) async {
    var recordedSession = await openTestScenario(tester, 'Manual RUM Scenario');

    var downloadButton =
        find.widgetWithText(ElevatedButton, 'Download Resource');
    await tester.tap(downloadButton);
    await tester.pumpAndSettle();

    var nextButton = find.widgetWithText(ElevatedButton, 'Next Screen');
    await tester.waitFor(
      nextButton,
      const Duration(seconds: 2),
      (e) => (e.widget as ElevatedButton).enabled,
    );
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    // wait for this view to throw an error and scroll
    nextButton = find.widgetWithText(ElevatedButton, 'Next Screen');
    await tester.waitFor(
      nextButton,
      const Duration(seconds: 5),
      (e) => (e.widget as ElevatedButton).enabled,
    );
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    var requestLog = <RequestLog>[];
    var rumLog = <RumEventDecoder>[];
    await recordedSession.pollSessionRequests(
      const Duration(seconds: 50),
      (requests) {
        requestLog.addAll(requests);
        requests.map((e) => e.data.split('\n')).expand((e) => e).forEach((e) {
          var jsonValue = json.decode(e);
          if (jsonValue is Map<String, dynamic>) {
            rumLog.add(RumEventDecoder(jsonValue));
          }
        });
        return RumSessionDecoder.fromEvents(rumLog).visits.length == 3;
      },
    );

    const contextKey = 'onboarding_stage';
    const expectedContextValue = 1;

    final session = RumSessionDecoder.fromEvents(rumLog);
    expect(session.visits.length, 3);

    final view1 = session.visits[0];
    expect(view1.name, 'RumManualInstrumentationScenario');
    expect(view1.path, 'RumManualInstrumentationScenario');
    expect(view1.viewEvents.last.view.actionCount, 3);
    expect(view1.viewEvents.last.view.resourceCount, 1);
    expect(view1.viewEvents.last.view.errorCount, 1);
    expect(view1.viewEvents.last.context[contextKey], expectedContextValue);
    expect(view1.actionEvents[0].actionType, 'application_start');
    expect(view1.actionEvents[1].actionType, 'tap');
    expect(view1.actionEvents[1].actionName, 'Tapped Download');
    expect(view1.actionEvents[1].context[contextKey], expectedContextValue);
    expect(view1.actionEvents[2].actionType, 'tap');
    expect(view1.actionEvents[2].actionName, 'Next Screen');
    expect(view1.actionEvents[2].context[contextKey], expectedContextValue);

    final contentReadyTiming =
        view1.viewEvents.last.view.customTimings['content-ready'];
    final firstInteractionTiming =
        view1.viewEvents.last.view.customTimings['first-interaction'];
    expect(contentReadyTiming, isNotNull);
    expect(contentReadyTiming, greaterThanOrEqualTo(50000));
    expect(contentReadyTiming, lessThan(2000000000));
    expect(firstInteractionTiming, isNotNull);
    expect(firstInteractionTiming, greaterThanOrEqualTo(contentReadyTiming!));
    expect(firstInteractionTiming, lessThan(8000000000));

    expect(view1.resourceEvents[0].url, 'https://fake_url/resource/1');
    expect(view1.resourceEvents[0].statusCode, 200);
    expect(view1.resourceEvents[0].resourceType, 'image');
    expect(view1.resourceEvents[0].duration,
        greaterThan((90 * 1000 * 1000) - 1)); // 90ms
    // TODO: Figure out why occasionally these have really high values
    // expect(view1.resourceEvents[0].duration,
    //     lessThan(10 * 1000 * 1000 * 1000)); // 10s
    expect(view1.resourceEvents[0].context[contextKey], expectedContextValue);

    expect(view1.errorEvents.length, 1);
    expect(view1.errorEvents[0].resourceUrl, 'https://fake_url/resource/2');
    expect(view1.errorEvents[0].message, 'Status code 400');
    expect(view1.errorEvents[0].errorType, 'ErrorLoading');
    expect(view1.errorEvents[0].source, 'network');
    expect(view1.errorEvents[0].context[contextKey], expectedContextValue);
    expect(view1, becameInactive);

    final view2 = session.visits[1];

    expect(view2.name, 'SecondManualRumView');
    expect(view2.path, 'RumManualInstrumentation2');
    expect(view2.viewEvents.last.view.actionCount, 2);
    expect(view2.viewEvents.last.view.resourceCount, 0);
    expect(view2.viewEvents.last.view.errorCount, 1);
    expect(view2.viewEvents.last.context[contextKey], expectedContextValue);
    expect(view2.errorEvents[0].message, 'Simulated view error');
    expect(view2.errorEvents[0].source, 'source');
    expect(view2.errorEvents[0].context[contextKey], expectedContextValue);
    expect(view2.actionEvents[0].actionType, 'scroll');
    expect(view2.actionEvents[0].actionName, 'User Scrolling');
    expect(view2.actionEvents[0].loadingTime,
        greaterThan(1800 * 1000 * 1000)); // 1.8s
    // TODO: Figure out why occasionally these have really high values
    // expect(view1.actionEvents[0].loadingTime,
    //     lessThan(3 * 1000 * 1000 * 1000)); // 3s
    expect(view2.actionEvents[0].context[contextKey], expectedContextValue);
    expect(view2.actionEvents[1].actionName, 'Next Screen');
    expect(view2.actionEvents[1].context[contextKey], expectedContextValue);

    expect(view2, becameInactive);

    final view3 = session.visits[2];
    expect(view3.name, 'ThirdManualRumView');
    expect(view3.path, 'screen3-widget');
    expect(view3.viewEvents.last.context[contextKey], isNull);
    expect(view3.viewEvents.last.view.actionCount, 0);
    expect(view3.viewEvents.last.view.resourceCount, 0);
    expect(view3.viewEvents.last.view.errorCount, 0);
  });
}

// MARK - Utilities

class _BecameInactiveMatcher extends Matcher {
  const _BecameInactiveMatcher();

  @override
  Description describe(Description description) {
    return description.add('was a view that eventually became inactive');
  }

  @override
  bool matches(item, Map matchState) {
    if (item is RumViewVisit) {
      return item.viewEvents.last.view.isActive == false;
    }
    return false;
  }
}

const becameInactive = _BecameInactiveMatcher();
// 