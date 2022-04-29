// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../common.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('test rum manual error reporting scenario',
      (WidgetTester tester) async {
    var recordedSession =
        await openTestScenario(tester, 'RUM Error Reporting Scenario');

    var throwButton =
        find.widgetWithText(ElevatedButton, 'Throw / Catch Exception');
    await tester.tap(throwButton);
    await tester.pumpAndSettle();

    var stopButton = find.widgetWithText(ElevatedButton, 'Stop View');
    await tester.tap(stopButton);
    await tester.pumpAndSettle();

    var requestLog = <RequestLog>[];
    var rumLog = <RumEventDecoder>[];
    await recordedSession.pollSessionRequests(
      const Duration(seconds: 30),
      (requests) {
        requestLog.addAll(requests);
        requests.map((e) => e.data.split('\n')).expand((e) => e).forEach((e) {
          var jsonValue = json.decode(e);
          if (jsonValue is Map<String, dynamic>) {
            rumLog.add(RumEventDecoder(jsonValue));
          }
        });
        var visits = RumSessionDecoder.fromEvents(rumLog).visits;
        return visits.length == 1 &&
            visits[0].viewEvents.last.view.errorCount == 3;
      },
    );

    final session = RumSessionDecoder.fromEvents(rumLog);
    expect(session.visits.length, 1);

    final view = session.visits[0];
    expect(view.viewEvents.last.view.errorCount, 3);
    expect(view.errorEvents.length, 3);

    var exceptionError = view.errorEvents[0];
    expect(exceptionError.message, NullThrownError().toString());
    expect(exceptionError.source, 'source');
    expect(exceptionError.sourceType, 'flutter');

    var manualError = view.errorEvents[1];
    expect(manualError.message, 'Rum error message');
    expect(manualError.source, 'network');

    var thrownError = view.errorEvents[2];
    expect(thrownError.message, contains('This was an error!'));
    expect(thrownError.source, 'source');
    expect(thrownError.stack, isNotNull);
  });
}
