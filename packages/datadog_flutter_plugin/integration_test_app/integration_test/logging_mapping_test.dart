// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_integration_test_app/integration_scenarios/scenario_runner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  kManualIsWeb = kIsWeb;

  testWidgets('logger with mapper modifies and excludes events',
      (tester) async {
    var recordedSession = await openTestScenario(
      tester,
      scenarioName: mappedLoggingScenarioRunner,
      menuTitle: 'Logging Scenario',
    );
    var logs = <LogDecoder>[];

    await recordedSession.pollSessionRequests(
      const Duration(seconds: 30),
      (requests) {
        requests
            .map((e) {
              try {
                return e.jsonData as List;
              } on FormatException {
                // Web sends as newline separated
                return e.data
                    .split('\n')
                    .map<dynamic>((e) => json.decode(e))
                    .toList();
              }
              // return null;
            })
            .whereType<List>()
            .expand<dynamic>((e) => e)
            .whereType<Map<String, Object?>>()
            // Ignore RUM sessions
            .where((e) => !(e).containsKey('session'))
            .forEach((e) => logs.add(LogDecoder(e)));
        return logs.length >= 5;
      },
    );

    // This is the same set of tests as logging_test.dart, except that:
    //   * logger-attribute2 should always be null
    //   * 'message' is replaced by 'xxxxxxxx'
    //   * the info message from the second_logger is not sent
    expect(logs.length, equals(5));

    expect(logs[0].status, 'debug');
    expect(logs[0].message, 'debug xxxxxxxx');
    // JS SDK doesn't support tags
    if (!kIsWeb) {
      expect(logs[0].tags, contains('tag1:tag-value'));
      expect(logs[0].tags, contains('my-tag'));
    }
    expect(logs[0].log['logger-attribute1'], 'string value');
    expect(logs[0].log['logger-attribute2'], isNull);
    expect(logs[0].log['stringAttribute'], 'string');

    expect(logs[1].status, 'info');
    expect(logs[1].message, 'info xxxxxxxx');
    if (!kIsWeb) {
      expect(logs[1].tags, isNot(contains('my-tag')));
      expect(logs[1].tags, contains('tag1:tag-value'));
    }
    expect(logs[1].log['logger-attribute1'], 'string value');
    expect(logs[1].log['logger-attribute2'], isNull);
    expect(logs[1].log['nestedAttribute'], containsPair('internal', 'test'));
    expect(logs[1].log['nestedAttribute'], containsPair('isValid', true));

    expect(logs[2].status, 'warn');
    expect(logs[2].message, 'warn xxxxxxxx');
    if (!kIsWeb) {
      expect(logs[2].tags, isNot(contains('my-tag')));
      expect(logs[2].tags, contains('tag1:tag-value'));
    }
    expect(logs[2].log['logger-attribute1'], 'string value');
    expect(logs[2].log['logger-attribute2'], isNull);
    expect(logs[2].log['doubleAttribute'], 10.34);

    expect(logs[3].status, 'error');
    expect(logs[3].message, 'error xxxxxxxx');
    if (!kIsWeb) {
      expect(logs[3].tags, isNot(contains('my-tag')));
      expect(logs[3].tags, isNot(contains('tag1:tag-value')));
    }
    expect(logs[3].log['logger-attribute1'], isNull);
    expect(logs[3].log['logger-attribute2'], isNull);
    expect(logs[3].log['attribute'], 'value');

    expect(logs[4].status, 'warn');
    expect(logs[4].message, 'Warning: this error occurred');
    expect(logs[4].log['second-logger-attribute'], 'second-value');
    expect(logs[4].log['logger-attribute1'], isNull);
    expect(logs[4].log['logger-attribute2'], isNull);
    expect(logs[4].errorMessage, 'Error Message');
    expect(logs[4].errorStack, isNotNull);
    expect(
        getNestedProperty<String>('logger.name', logs[5].log), 'second_logger');

    for (final log in logs) {
      expect(log.serviceName,
          equalsIgnoringCase('com.datadoghq.flutter.integration'));
      if (!kIsWeb) {
        if (Platform.isIOS) {
          expect(log.applicationVersion, '1.2.3-555');
        }
        expect(log.threadName, 'main');
      }
    }
  });
}
