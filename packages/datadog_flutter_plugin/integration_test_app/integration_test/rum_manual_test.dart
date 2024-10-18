// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';

Future<void> performUserInteractions(WidgetTester tester) async {
  var downloadButton = find.widgetWithText(ElevatedButton, 'Download Resource');
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

  var longTaskButton = find.widgetWithText(ElevatedButton, 'Trigger Long Task');
  await tester.waitFor(
    longTaskButton,
    const Duration(seconds: 5),
    (e) => (e.widget as ElevatedButton).enabled,
  );
  await tester.tap(longTaskButton);
  await tester.pumpAndSettle(const Duration(milliseconds: 300));

  nextButton = find.widgetWithText(ElevatedButton, 'Next Screen');
  await tester.waitFor(
    nextButton,
    const Duration(seconds: 2),
    (e) => (e.widget as ElevatedButton).enabled,
  );
  await tester.tap(nextButton);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('test rum scenario', (WidgetTester tester) async {
    var recordedSession = await openTestScenario(
      tester,
      menuTitle: 'Manual RUM Scenario',
    );

    await performUserInteractions(tester);

    var requestLog = <RequestLog>[];
    var rumLog = <RumEventDecoder>[];
    await recordedSession.pollSessionRequests(
      const Duration(seconds: 50),
      (requests) {
        requestLog.addAll(requests);
        requests.map((e) => e.data.split('\n')).expand((e) => e).forEach((e) {
          dynamic jsonValue = json.decode(e);
          if (jsonValue is Map<String, Object?>) {
            final rumEvent = RumEventDecoder.fromJson(jsonValue);
            if (rumEvent != null) {
              rumLog.add(rumEvent);
            }
          }
        });
        return RumSessionDecoder.fromEvents(rumLog).visits.length >=
            (kIsWeb ? 4 : 3);
      },
    );

    const contextKey = 'onboarding_stage';
    const expectedContextValue = 1;

    for (var log in requestLog) {
      verifyCommonTags(
        log,
        'com.datadoghq.flutter.integration',
        '1.2.3-555',
        'integration',
      );
    }

    final session = RumSessionDecoder.fromEvents(rumLog);
    expect(session.visits.length, kIsWeb ? 4 : 3);

    final view1 = session.visits[0];
    expect(view1.name, 'RumManualInstrumentationScenario');
    if (kIsWeb) {
      // Make sure we're sending a path, but mostly it won't change.
      expect(view1.path, startsWith('http://localhost'));
    } else {
      expect(view1.path, 'RumManualInstrumentationScenario');
    }

    // In some cases, application_start doesn't get associated to the first view
    var actionCount = 2;
    var baseAction = 0;
    if (view1.actionEvents[0].actionType == 'application_start') {
      actionCount = 3;
      baseAction = 1;
    }
    expect(view1.viewEvents.last.view.actionCount, actionCount);

    if (!kIsWeb) {
      // Manual resources on web don't work (the error is a resource loading error)
      expect(view1.viewEvents.last.view.resourceCount, 1);
      expect(view1.viewEvents.last.view.errorCount, 1);
    }
    expect(view1.viewEvents.last.context![contextKey], expectedContextValue);
    expect(view1.viewEvents.last.featureFlags?.isEmpty, isTrue);

    expect(view1.actionEvents[baseAction + 0].actionType,
        kIsWeb ? 'custom' : 'tap');
    expect(view1.actionEvents[baseAction + 0].actionName, 'Tapped Download');
    expect(view1.actionEvents[baseAction + 0].context![contextKey],
        expectedContextValue);
    expect(view1.actionEvents[baseAction + 1].actionType,
        kIsWeb ? 'custom' : 'tap');
    expect(view1.actionEvents[baseAction + 1].actionName, 'Next Screen');
    expect(view1.actionEvents[baseAction + 1].context![contextKey],
        expectedContextValue);

    final contentReadyTiming =
        view1.viewEvents.last.view.customTimings['content-ready'];
    final viewLoadingTiming = view1.viewEvents.last.view.loadingTime;
    final firstInteractionTiming =
        view1.viewEvents.last.view.customTimings['first-interaction'];
    expect(contentReadyTiming, isNotNull);
    expect(contentReadyTiming, greaterThanOrEqualTo(50 * 1000 * 1000));
    // TODO: Figure out why occasionally these have really high values
    // expect(contentReadyTiming, lessThan(200 * 1000 * 100));
    if (!kIsWeb) {
      expect(viewLoadingTiming, isNotNull);
      expect(viewLoadingTiming,
          closeTo(contentReadyTiming!, 5000000)); // Within 5ms
    }
    expect(firstInteractionTiming, isNotNull);
    expect(firstInteractionTiming, greaterThanOrEqualTo(contentReadyTiming!));
    // TODO: Figure out why occasionally these have really high values
    // expect(firstInteractionTiming, lessThan(800 * 1000 * 1000));

    // Manual resource loading calls are ignored on Web.
    if (!kIsWeb) {
      expect(view1.resourceEvents[0].url, 'https://fake_url/resource/1');
      expect(view1.resourceEvents[0].statusCode, 200);
      expect(view1.resourceEvents[0].resourceType, 'image');
      expect(view1.resourceEvents[0].duration,
          greaterThan((90 * 1000 * 1000) - 1)); // 90ms
      // TODO: Figure out why occasionally these have really high values
      // expect(view1.resourceEvents[0].duration,
      //     lessThan(10 * 1000 * 1000 * 1000)); // 10s
      expect(
          view1.resourceEvents[0].context![contextKey], expectedContextValue);

      expect(view1.errorEvents.length, 1);
      expect(view1.errorEvents[0].resourceUrl, 'https://fake_url/resource/2');
      expect(view1.errorEvents[0].message, 'Status code 400');
      expect(view1.errorEvents[0].errorType, 'ErrorLoading');
      expect(view1.errorEvents[0].source, 'network');
      expect(view1.errorEvents[0].context![contextKey], expectedContextValue);
    }

    // Verify user in all events, except for the first view event
    for (final viewEvent in view1.viewEvents.sublist(1)) {
      verifyUser(viewEvent);
    }
    for (final actionEvent in view1.actionEvents) {
      verifyUser(actionEvent);
    }
    for (final resourceEvent in view1.resourceEvents) {
      verifyUser(resourceEvent);
    }
    for (final errorEvent in view1.errorEvents) {
      verifyUser(errorEvent);
    }

    expect(view1, becameInactive);

    final view2 = session.visits[1];

    expect(view2.name, 'SecondManualRumView');
    if (kIsWeb) {
      // Make sure we're sending a path, but mostly it won't change.
      expect(view2.path, startsWith('http://localhost'));
    } else {
      expect(view2.path, 'RumManualInstrumentation2');
    }
    expect(view2.viewEvents.last.view.errorCount, 1);
    expect(view2.viewEvents.last.view.actionCount, kIsWeb ? 1 : 2);
    // We can have multiple long tasks
    expect(view2.viewEvents.last.view.longTaskCount, greaterThanOrEqualTo(1));
    if (!kIsWeb) {
      // Web can download extra resources
      expect(view2.viewEvents.last.view.resourceCount, 0);
    }
    if (!kIsWeb) {
      // The removal of this key happens at a weird point for web, so
      // let's not check it for now.
      expect(view2.viewEvents.last.context![contextKey], expectedContextValue);
    }
    expect(view2.viewEvents.last.featureFlags?['mock_flag_a'], false);
    expect(view2.viewEvents.last.featureFlags?['mock_flag_b'], 'mock_value');

    expect(view2.errorEvents[0].message, 'Simulated view error');
    expect(view2.errorEvents[0].source, kIsWeb ? 'custom' : 'source');
    expect(view2.errorEvents[0].context![contextKey], expectedContextValue);
    expect(view2.errorEvents[0].context!['custom_attribute'], 'my_attribute');
    expect(view2.errorEvents[0].fingerprint, 'custom-fingerprint');

    // Check all long tasks are over 100 ms (the default) and that one is greater
    // than 200 ms (triggered by the tapping of the button)
    // On web, we can't configure the long task threshold, so it becomes 50ms
    const longTaskThresholdMs = kIsWeb ? 50 : 100;
    var over200 = 0;
    for (var longTask in view2.longTaskEvents) {
      expect(
          longTask.duration,
          greaterThanOrEqualTo(
              const Duration(milliseconds: longTaskThresholdMs).inNanoseconds));
      // Nothing should have taken more than 2 seconds
      expect(longTask.duration,
          lessThan(const Duration(seconds: 2).inNanoseconds));
      if (longTask.duration! >
          const Duration(milliseconds: 200).inNanoseconds) {
        over200++;
      }
    }
    expect(over200, greaterThanOrEqualTo(1));

    // Web doesn't support start/stopAction
    RumActionEventDecoder tapAction;
    if (!kIsWeb) {
      expect(view2.actionEvents[0].actionType, 'scroll');
      expect(view2.actionEvents[0].actionName, 'User Scrolling');

      expect(view2.actionEvents[0].loadingTime,
          greaterThan(1800 * 1000 * 1000)); // 1.8s
      // TODO: Figure out why occasionally these have really high values
      // expect(view1.actionEvents[0].loadingTime,
      //     lessThan(3 * 1000 * 1000 * 1000)); // 3s
      expect(view2.actionEvents[0].context![contextKey], expectedContextValue);
      tapAction = view2.actionEvents[1];
    } else {
      tapAction = view2.actionEvents[0];
    }

    expect(tapAction.actionName, 'Next Screen');
    expect(tapAction.context![contextKey], expectedContextValue);

    expect(view2, becameInactive);

    final view3 = session.visits[2];
    expect(view3.name, 'ThirdManualRumView');
    if (kIsWeb) {
      // Make sure we're sending a path, but mostly it won't change.
      expect(view3.path, startsWith('http://localhost'));
    } else {
      expect(view3.path, 'screen3-widget');
    }

    // There seems to be a weird race condition around when this context
    // variable is removed on web
    if (!kIsWeb) {
      expect(view3.viewEvents.last.context?[contextKey], isNull);
    }
    expect(view3.viewEvents.last.view.actionCount, 0);
    expect(view3.viewEvents.last.view.errorCount, 0);

    const expectedNestedAttribute = {
      'testing_attribute': {
        'nested_1': 123,
        'nested_null': null,
      },
    };
    expect(view3.viewEvents.last.context!['nesting_attribute'],
        expectedNestedAttribute);

    // Verify service name in RUM events
    for (final event in rumLog) {
      if (!kIsWeb && Platform.isIOS && event.eventType != 'telemetry') {
        expect(event.service, 'com.datadoghq.flutter.integration');
        expect(event.version, '1.2.3-555');
      }
    }
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
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is RumViewVisit) {
      return item.viewEvents.last.view.isActive == false;
    }
    return false;
  }
}

const becameInactive = _BecameInactiveMatcher();
// 