// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('test background isolate scenario', (WidgetTester tester) async {
    var recordedSession = await openTestScenario(
      tester,
      menuTitle: 'Isolate Tracking Scenario',
    );

    var requestLog = <RequestLog>[];
    var rumLog = <RumEventDecoder>[];
    var logLog = <LogDecoder>[];
    await recordedSession.pollSessionRequests(
      const Duration(seconds: 50),
      (requests) {
        requestLog.addAll(requests);
        for (var e in requests) {
          final asLogs = e.asLogs();
          if (asLogs != null && asLogs.isNotEmpty) {
            logLog.addAll(asLogs);
          } else {
            e.data.split('\n').forEach((e) {
              dynamic jsonValue = json.decode(e);
              if (jsonValue is Map<String, Object?>) {
                final rumEvent = RumEventDecoder.fromJson(jsonValue);
                if (rumEvent != null) {
                  rumLog.add(rumEvent);
                }
              }
            });
          }
        }
        final rumSession = RumSessionDecoder.fromEvents(rumLog);
        return logLog.length >= 2 &&
            rumSession.visits.length == 1 &&
            rumSession.visits[0].resourceEvents.isNotEmpty &&
            rumSession.visits[0].errorEvents.isNotEmpty;
      },
    );

    final firstLog = logLog[0];
    expect(firstLog.status, 'info');
    expect(firstLog.message, 'Message from background isolate!');

    final secondLog = logLog[1];
    expect(secondLog.status, 'warn');
    expect(secondLog.message, 'Finished with background isolate!');

    final session = RumSessionDecoder.fromEvents(rumLog);
    final view1 = session.visits[0];

    final manualResourceEvents = view1.resourceEvents
        .where((e) => e.url == 'https://fake_url/resource/1')
        .toList();
    expect(manualResourceEvents.length, 1);
    expect(manualResourceEvents[0].statusCode, 200);
    expect(manualResourceEvents[0].resourceType, 'image');
    final resourceDuration = manualResourceEvents[0].duration;
    expect(resourceDuration,
        greaterThan(const Duration(milliseconds: 90).inNanoseconds - 1));
    expect(
        resourceDuration, lessThan(const Duration(seconds: 10).inNanoseconds));

    expect(view1.errorEvents.length, 1);
    expect(view1.errorEvents[0].resourceUrl, 'https://fake_url/resource/2');
    expect(view1.errorEvents[0].message, 'Status code 400');
    expect(view1.errorEvents[0].errorType, 'ErrorLoading');
    expect(view1.errorEvents[0].source, 'network');
  });
}
