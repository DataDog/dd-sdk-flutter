// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../common.dart';
import '../tools/mock_http_sever.dart';
import 'rum_decoder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('test rum scenario', (WidgetTester tester) async {
    await openTestScenario(tester, 'Manual RUM Scenario');

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

    // wait for this fiew to throw an error
    await Future.delayed(Duration(milliseconds: 100));
    nextButton = find.widgetWithText(ElevatedButton, 'Next Screen');
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    var requestLog = <RequestLog>[];
    var rumLog = <RumEventDecoder>[];
    await mockHttpServer!.pollRequests(
      const Duration(seconds: 30),
      (requests) {
        requestLog.addAll(requests);
        requests.map((e) => e.data.split('\n')).expand((e) => e).forEach((e) {
          var jsonValue = json.decode(e);
          if (jsonValue is Map<String, dynamic>) {
            rumLog.add(RumEventDecoder(jsonValue));
          }
        });
        return RumSessionDecoder.fromEvents(rumLog).visits.length == 2;
      },
    );

    final session = RumSessionDecoder.fromEvents(rumLog);
    expect(session.visits.length, 3);

    final view1 = session.visits[0];
    expect(view1.name, 'RumManualInstrumentationScenario');
    expect(view1.path, 'RumManualInstrumentationScenario');
    expect(view1.viewEvents.last.view.actionCount, 1);
    expect(view1.actionEvents[0].actionType, 'application_start');

    final contentReadyTiming =
        view1.viewEvents.last.view.customTimings['content-ready'];
    final firstInteractionTiming =
        view1.viewEvents.last.view.customTimings['first-interaction'];
    expect(contentReadyTiming, isNotNull);
    expect(contentReadyTiming, greaterThanOrEqualTo(50000));
    expect(contentReadyTiming, lessThan(1000000000));
    expect(firstInteractionTiming, isNotNull);
    expect(firstInteractionTiming, greaterThanOrEqualTo(contentReadyTiming!));
    expect(firstInteractionTiming, lessThan(5000000000));
    expect(view1, becameInactive);

    final view2 = session.visits[1];
    expect(view2.name, 'SecondManualRumView');
    expect(view2.path, 'RumManualInstrumentation2');
    expect(view2.viewEvents.last.view.actionCount, 0);
    expect(view2, becameInactive);

    final view3 = session.visits[2];
    expect(view3.name, 'ThirdManualRumView');
    expect(view3.path, 'screen3-widget');
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

extension Waiter on WidgetTester {
  Future<bool> waitFor(
    Finder finder,
    Duration timeout,
    bool Function(Element e) predicate,
  ) async {
    var endtime = DateTime.now().add(timeout);
    bool wasFound = false;
    while (DateTime.now().isBefore(endtime) && !wasFound) {
      final element = finder.evaluate().firstOrNull;
      if (element != null) {
        wasFound = predicate(element);
      }
      await pumpAndSettle();
    }

    return wasFound;
  }
}
