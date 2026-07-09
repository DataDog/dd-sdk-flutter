// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_common_test/widget_tester_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';

Future<void> performUserInteractions(WidgetTester tester) async {
  final startButton = find.widgetWithText(ElevatedButton, 'Start Session');
  await tester.tap(startButton);
  await tester.pumpAndSettle();

  final downloadResourceButton =
      find.widgetWithText(ElevatedButton, 'Download Resource');
  await tester.tap(downloadResourceButton);
  await tester.pumpAndSettle();
  await tester.waitFor(downloadResourceButton, const Duration(seconds: 2),
      (e) => (e.widget as ElevatedButton).enabled);

  final userActionButton = find.widgetWithText(ElevatedButton, 'User Action');
  await tester.tap(userActionButton);
  await tester.pumpAndSettle();

  await tester.pageBack();

  // Wait
  await tester.pump(const Duration(milliseconds: 500));

  // Next session
  await tester.tap(startButton);
  await tester.pumpAndSettle();

  await tester.tap(downloadResourceButton);
  await tester.pumpAndSettle();
  await tester.waitFor(downloadResourceButton, const Duration(seconds: 2),
      (e) => (e.widget as ElevatedButton).enabled);
  await tester.tap(userActionButton);
  await tester.pumpAndSettle();

  final finishButton = find.widgetWithText(ElevatedButton, 'Finish Test');
  await tester.tap(finishButton);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('test rum scenario', (WidgetTester tester) async {
    var recordedSession = await openTestScenario(
      tester,
      menuTitle: 'Kiosk RUM Scenario',
    );

    await performUserInteractions(tester);

    var requestLog = <RequestLog>[];
    var rumLog = <RumEventDecoder>[];
    await recordedSession.pollSessionRequests(
      const Duration(seconds: 80),
      (requests) {
        requestLog.addAll(requests);
        rumLog.addAll(requests.expand((r) => r.asRumEvents()));
        final allSessions = RumSessionDecoder.fromEvents(rumLog);
        return allSessions.fold<int>(0, (sum, s) => sum + s.visits.length) >=
            (kIsWeb ? 5 : 3);
      },
    );

    final sessions = RumSessionDecoder.fromEvents(rumLog);
    expect(sessions.length, greaterThanOrEqualTo(2));

    final firstSessionDecoder = sessions[0];
    final secondSessionDecoder = sessions[1];

    final firstSessionId = firstSessionDecoder
        .visits[0].viewEvents[0].rumEvent['session']['id'] as String;
    final secondSessionId = secondSessionDecoder
        .visits[0].viewEvents[0].rumEvent['session']['id'] as String;

    expect(firstSessionId, isNot(secondSessionId));
    final firstVisit = firstSessionDecoder.visits[0];
    for (final viewEvent in firstVisit.viewEvents) {
      expect(viewEvent.rumEvent['session']['id'], firstSessionId);
    }
    if (!isDdSdkCppPlatform()) {
      expect(
          firstVisit.viewEvents.last.rumEvent['session']['is_active'], isFalse);
    }

    expect(firstVisit.resourceEvents.length, 1);
    expect(
        firstVisit.resourceEvents[0].rumEvent['session']['id'], firstSessionId);
    expect(firstVisit.actionEvents.length, 1);
    expect(
        firstVisit.actionEvents[0].rumEvent['session']['id'], firstSessionId);

    final secondVisit = secondSessionDecoder.visits[0];
    for (final viewEvent in secondVisit.viewEvents) {
      expect(viewEvent.rumEvent['session']['id'], secondSessionId);
    }
    if (!isDdSdkCppPlatform()) {
      expect(
          secondVisit.viewEvents.last.rumEvent['session']['is_active'], isTrue);
    }

    expect(secondVisit.resourceEvents.length, 1);
    expect(secondVisit.resourceEvents[0].rumEvent['session']['id'],
        secondSessionId);
    expect(secondVisit.actionEvents.length, 1);
    expect(
        secondVisit.actionEvents[0].rumEvent['session']['id'], secondSessionId);
  });
}
