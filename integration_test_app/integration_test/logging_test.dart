// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';

class LogKeys {
  static const date = 'date';
  static const status = 'status';

  static const message = 'message';
  static const serviceName = 'service';
  static const tags = 'ddtags';

  static const applicationVersion = 'version';

  static const loggerName = 'logger.name';
  static const loggerVersion = 'logger.version';
  static const threadName = 'logger.thread_name';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('test logging scenario', (WidgetTester tester) async {
    await openTestScenario(tester, 'Logging Scenario');

    var logs = <Map<String, Object?>>[];

    await mockHttpServer!.pollRequests(
      const Duration(seconds: 30),
      (requests) {
        requests
            .map((e) => (e.requestJson as List))
            .expand((e) => e)
            .forEach((e) => logs.add(e as Map<String, dynamic>));

        return logs.length >= 4;
      },
    );
    expect(logs.length, greaterThanOrEqualTo(4));

    expect(logs[0][LogKeys.status], 'debug');
    expect(logs[0][LogKeys.message], 'debug message');
    expect(logs[0][LogKeys.tags], contains('tag1:tag-value'));
    expect(logs[0][LogKeys.tags], contains('my-tag'));
    expect(logs[0]['stringAttribute'], 'string');

    expect(logs[1][LogKeys.status], 'info');
    expect(logs[1][LogKeys.message], 'info message');
    expect(logs[1][LogKeys.tags], isNot(contains('my-tag')));
    expect(logs[1][LogKeys.tags], contains('tag1:tag-value'));
    expect(logs[1]['nestedAttribute'], containsPair('internal', 'test'));
    expect(logs[1]['nestedAttribute'], containsPair('isValid', true));

    expect(logs[2][LogKeys.status], 'warn');
    expect(logs[2][LogKeys.message], 'warn message');
    expect(logs[2][LogKeys.tags], isNot(contains('my-tag')));
    expect(logs[2][LogKeys.tags], contains('tag1:tag-value'));
    expect(logs[2]['doubleAttribute'], 10.34);

    expect(logs[3][LogKeys.status], 'error');
    expect(logs[3][LogKeys.message], 'error message');
    expect(logs[3][LogKeys.tags], isNot(contains('my-tag')));
    expect(logs[3][LogKeys.tags], isNot(contains('tag1:tag-value')));
    expect(logs[3]['attribute'], 'value');

    for (final log in logs) {
      if (log.containsKey('logger-attribute1')) {
        expect(log['logger-attribute1'], 'string value');
      }
      // All logs should have logger-attribute2
      expect(log['logger-attribute2'], 1000);

      expect(log[LogKeys.serviceName],
          equalsIgnoringCase('com.datadoghq.flutter.integrationtestapp'));

      if (Platform.isIOS) {
        expect(log[LogKeys.threadName], 'main');
      }
    }
  });
}
