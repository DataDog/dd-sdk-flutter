// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.
import 'dart:convert';
import 'dart:io';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  kManualIsWeb = kIsWeb;

  testWidgets('test logging scenario', (WidgetTester tester) async {
    var recordedSession = await openTestScenario(
      tester,
      menuTitle: 'Logging Scenario',
      additionalConfig: {
        DatadogConfigKey.telemetryConfigurationSampleRate: 0.0,
      },
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
                // This might be the telemetry event
                return null;
              }
              // return null;
            })
            .whereType<List>()
            .expand<dynamic>((e) => e)
            .whereType<Map<String, Object?>>()
            // Ignore RUM sessions and telemetry
            .where((e) {
              return !(e).containsKey('session') && e['type'] != 'telemetry';
            })
            .forEach((e) => logs.add(LogDecoder(e)));
        return logs.length >= 6;
      },
    );
    expect(logs.length, greaterThanOrEqualTo(6));

    List<LogDecoder> firstLoggerLogs =
        logs.where((l) => l.loggerName != 'second_logger').toList();

    expect(firstLoggerLogs[0].status, 'debug');
    expect(firstLoggerLogs[0].message, 'debug message');
    // JS SDK doesn't support tags
    if (!kIsWeb) {
      expect(firstLoggerLogs[0].tags, contains('tag1:tag-value'));
      expect(firstLoggerLogs[0].tags, contains('my-tag'));
    }
    expect(firstLoggerLogs[0].log['logger-attribute1'], 'string value');
    expect(firstLoggerLogs[0].log['logger-attribute2'], 1000);
    expect(firstLoggerLogs[0].log['stringAttribute'], 'string');

    expect(firstLoggerLogs[1].status, 'info');
    expect(firstLoggerLogs[1].message, 'info message');
    if (!kIsWeb) {
      expect(firstLoggerLogs[1].tags, isNot(contains('my-tag')));
      expect(firstLoggerLogs[1].tags, contains('tag1:tag-value'));
    }
    expect(firstLoggerLogs[1].log['logger-attribute1'], 'string value');
    expect(firstLoggerLogs[1].log['logger-attribute2'], 1000);
    expect(firstLoggerLogs[1].log['nestedAttribute'],
        containsPair('internal', 'test'));
    expect(firstLoggerLogs[1].log['nestedAttribute'],
        containsPair('isValid', true));

    expect(firstLoggerLogs[2].status, 'warn');
    expect(firstLoggerLogs[2].message, 'warn message');
    if (!kIsWeb) {
      expect(firstLoggerLogs[2].tags, isNot(contains('my-tag')));
      expect(firstLoggerLogs[2].tags, contains('tag1:tag-value'));
    }
    expect(firstLoggerLogs[2].log['logger-attribute1'], 'string value');
    expect(firstLoggerLogs[2].log['logger-attribute2'], 1000);
    expect(firstLoggerLogs[2].log['doubleAttribute'], 10.34);

    expect(firstLoggerLogs[3].status, 'error');
    expect(firstLoggerLogs[3].message, 'error message');
    if (!kIsWeb) {
      expect(firstLoggerLogs[3].tags, isNot(contains('my-tag')));
      expect(firstLoggerLogs[3].tags, isNot(contains('tag1:tag-value')));
    }
    expect(firstLoggerLogs[3].log['logger-attribute1'], isNull);
    expect(firstLoggerLogs[3].log['logger-attribute2'], 1000);
    expect(firstLoggerLogs[3].log['attribute'], 'value');

    List<LogDecoder> secondLoggerLogs =
        logs.where((l) => l.loggerName == 'second_logger').toList();

    expect(secondLoggerLogs[0].status, 'info');
    expect(secondLoggerLogs[0].message, 'message on second logger');
    expect(secondLoggerLogs[0].log['second-logger-attribute'], 'second-value');
    expect(secondLoggerLogs[0].log['logger-attribute1'], isNull);
    expect(secondLoggerLogs[0].log['logger-attribute2'], isNull);
    expect(getNestedProperty<String>('logger.name', secondLoggerLogs[1].log),
        'second_logger');

    expect(secondLoggerLogs[1].status, 'warn');
    expect(secondLoggerLogs[1].message, 'Warning: this error occurred');
    expect(secondLoggerLogs[1].log['second-logger-attribute'], 'second-value');
    expect(secondLoggerLogs[1].log['logger-attribute1'], isNull);
    expect(secondLoggerLogs[1].log['logger-attribute2'], isNull);
    expect(secondLoggerLogs[1].errorMessage, 'Error Message');
    expect(secondLoggerLogs[1].errorStack, isNotNull);
    expect(getNestedProperty<String>('logger.name', secondLoggerLogs[1].log),
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
