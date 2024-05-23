// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
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
      additionalConfig: {
        DatadogConfigKey.telemetryConfigurationSampleRate: 0.0,
      },
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
              } on TypeError {
                // This is likely from RUM Telemetry
                return null;
              }
            })
            .whereType<List<dynamic>>()
            .expand<dynamic>((e) => e)
            .whereType<Map<String, Object?>>()
            // Ignore RUM sessions
            .where(
                (e) => !(e).containsKey('session') && e['type'] != 'telemetry')
            .forEach((e) => logs.add(LogDecoder(e)));
        return logs.length >= 6;
      },
    );

    // This is the same set of tests as logging_test.dart, except that:
    //   * logger-attribute2 should always be null
    //   * 'message' is replaced by 'xxxxxxxx'
    //   * the info message from the second_logger is not sent
    //   * all error fingerprints on the second-logger are replaced with 'mapped print'
    expect(logs.length, equals(6));

    List<LogDecoder> firstLoggerLogs =
        logs.where((l) => l.loggerName != 'second_logger').toList();

    expect(firstLoggerLogs[0].status, 'debug');
    expect(firstLoggerLogs[0].message, 'debug xxxxxxxx');
    // JS SDK doesn't support tags
    if (!kIsWeb) {
      expect(firstLoggerLogs[0].tags, contains('tag1:tag-value'));
      expect(firstLoggerLogs[0].tags, contains('my-tag'));
    }
    expect(firstLoggerLogs[0].log['logger-attribute1'], 'string value');
    expect(firstLoggerLogs[0].log['logger-attribute2'], isNull);
    expect(firstLoggerLogs[0].log['stringAttribute'], 'string');

    expect(firstLoggerLogs[1].status, 'info');
    expect(firstLoggerLogs[1].message, 'info xxxxxxxx');
    if (!kIsWeb) {
      expect(firstLoggerLogs[1].tags, isNot(contains('my-tag')));
      expect(firstLoggerLogs[1].tags, contains('tag1:tag-value'));
    }
    expect(firstLoggerLogs[1].log['logger-attribute1'], 'string value');
    expect(firstLoggerLogs[1].log['logger-attribute2'], isNull);
    expect(firstLoggerLogs[1].log['nestedAttribute'],
        containsPair('internal', 'test'));
    expect(firstLoggerLogs[1].log['nestedAttribute'],
        containsPair('isValid', true));

    expect(firstLoggerLogs[2].status, 'warn');
    expect(firstLoggerLogs[2].message, 'warn xxxxxxxx');
    if (!kIsWeb) {
      expect(firstLoggerLogs[2].tags, isNot(contains('my-tag')));
      expect(firstLoggerLogs[2].tags, contains('tag1:tag-value'));
    }
    expect(firstLoggerLogs[2].log['logger-attribute1'], 'string value');
    expect(firstLoggerLogs[2].log['logger-attribute2'], isNull);
    expect(firstLoggerLogs[2].log['doubleAttribute'], 10.34);

    expect(firstLoggerLogs[3].status, 'error');
    expect(firstLoggerLogs[3].message, 'error xxxxxxxx');
    if (!kIsWeb) {
      expect(firstLoggerLogs[3].tags, isNot(contains('my-tag')));
      expect(firstLoggerLogs[3].tags, isNot(contains('tag1:tag-value')));
    }
    expect(firstLoggerLogs[3].log['logger-attribute1'], isNull);
    expect(firstLoggerLogs[3].log['logger-attribute2'], isNull);
    expect(firstLoggerLogs[3].log['attribute'], 'value');

    expect(firstLoggerLogs[4].status, 'error');
    expect(firstLoggerLogs[4].message, 'Encountered an error');
    expect(firstLoggerLogs[4].errorMessage, isNotNull);
    if (!kIsWeb) {
      expect(firstLoggerLogs[4].errorSourceType, 'flutter');
      expect(firstLoggerLogs[4].tags, isNot(contains('my-tag')));
      expect(firstLoggerLogs[4].tags, isNot(contains('tag1:tag-value')));
    }
    expect(firstLoggerLogs[4].log['logger-attribute1'], isNull);
    expect(firstLoggerLogs[4].log['logger-attribute2'], isNull);

    List<LogDecoder> secondLoggerLogs =
        logs.where((l) => l.loggerName == 'second_logger').toList();

    expect(secondLoggerLogs[0].status, 'warn');
    expect(secondLoggerLogs[0].message, 'Warning: this error occurred');
    expect(secondLoggerLogs[0].log['second-logger-attribute'], 'second-value');
    expect(secondLoggerLogs[0].log['logger-attribute1'], isNull);
    expect(secondLoggerLogs[0].log['logger-attribute2'], isNull);
    expect(secondLoggerLogs[0].errorMessage, 'Error Message');
    expect(secondLoggerLogs[0].errorStack, isNotNull);
    expect(secondLoggerLogs[0].errorFingerprint, 'mapped print');
    expect(getNestedProperty<String>('logger.name', secondLoggerLogs[0].log),
        'second_logger');

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
