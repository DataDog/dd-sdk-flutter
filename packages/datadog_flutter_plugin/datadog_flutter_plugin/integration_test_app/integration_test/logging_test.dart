// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.
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

    await recordedSession.pollForLogs(
      const Duration(seconds: 45),
      (requestLogs) {
        logs = requestLogs;
        return logs.length >= 8;
      },
    );
    expect(logs.length, greaterThanOrEqualTo(8));

    List<LogDecoder> firstLoggerLogs =
        logs.where((l) => l.loggerName != 'second_logger').toList();
    if (!kIsWeb) {
      for (final log in firstLoggerLogs) {
        if (Platform.isAndroid) {
          expect(log.log['network'], isNotNull);
        } else if (Platform.isIOS) {
          expect(log.log['network.client.reachability'], isNotNull);
        }
      }
    }

    expect(firstLoggerLogs[0].status, 'debug');
    expect(firstLoggerLogs[0].message, 'debug message');
    expect(firstLoggerLogs[0].tags, contains('tag1:tag-value'));
    expect(firstLoggerLogs[0].tags, contains('my-tag'));
    expect(firstLoggerLogs[0].log['logger-attribute1'], 'string value');
    expect(firstLoggerLogs[0].log['logger-attribute2'], 1000);
    expect(firstLoggerLogs[0].log['stringAttribute'], 'string');
    expect(firstLoggerLogs[0].log['global-attribute'], isNull);

    expect(firstLoggerLogs[1].status, 'info');
    expect(firstLoggerLogs[1].message, 'info message');
    expect(firstLoggerLogs[1].tags, isNot(contains('my-tag')));
    expect(firstLoggerLogs[1].tags, contains('tag1:tag-value'));
    expect(firstLoggerLogs[1].log['logger-attribute1'], 'string value');
    expect(firstLoggerLogs[1].log['logger-attribute2'], 1000);
    expect(firstLoggerLogs[1].log['nestedAttribute'],
        containsPair('internal', 'test'));
    expect(firstLoggerLogs[1].log['nestedAttribute'],
        containsPair('isValid', true));
    expect(firstLoggerLogs[1].log['global-attribute'], isNull);

    expect(firstLoggerLogs[2].status, 'warn');
    expect(firstLoggerLogs[2].message, 'warn message');
    expect(firstLoggerLogs[2].tags, isNot(contains('my-tag')));
    expect(firstLoggerLogs[2].tags, contains('tag1:tag-value'));
    expect(firstLoggerLogs[2].log['logger-attribute1'], 'string value');
    expect(firstLoggerLogs[2].log['logger-attribute2'], 1000);
    expect(firstLoggerLogs[2].log['doubleAttribute'], 10.34);
    expect(firstLoggerLogs[2].log['global-attribute'], isNull);

    expect(firstLoggerLogs[3].status, 'error');
    expect(firstLoggerLogs[3].message, 'error message');
    expect(firstLoggerLogs[3].tags, isNot(contains('my-tag')));
    expect(firstLoggerLogs[3].tags, isNot(contains('tag1:tag-value')));
    expect(firstLoggerLogs[3].log['logger-attribute1'], isNull);
    expect(firstLoggerLogs[3].log['logger-attribute2'], 1000);
    expect(firstLoggerLogs[3].log['attribute'], 'value');
    expect(firstLoggerLogs[3].log['global-attribute'], 'global value');

    expect(firstLoggerLogs[4].status, 'error');
    expect(firstLoggerLogs[4].message, 'Encountered an error');
    expect(firstLoggerLogs[4].errorMessage, isNotNull);
    if (!kIsWeb) {
      // Errors from web will always be `browser`
      expect(firstLoggerLogs[4].errorSourceType, 'flutter');
    }
    expect(firstLoggerLogs[4].tags, isNot(contains('my-tag')));
    expect(firstLoggerLogs[4].tags, isNot(contains('tag1:tag-value')));
    expect(firstLoggerLogs[4].log['logger-attribute1'], isNull);
    expect(firstLoggerLogs[4].log['logger-attribute2'], 1000);
    expect(firstLoggerLogs[4].log['global-attribute'], 'global value');

    List<LogDecoder> secondLoggerLogs =
        logs.where((l) => l.loggerName == 'second_logger').toList();
    if (!kIsWeb) {
      for (final log in secondLoggerLogs) {
        if (Platform.isAndroid) {
          expect(log.log['network'], isNull);
        } else if (Platform.isIOS) {
          expect(log.log['network.client.reachability'], isNull);
        }
      }
    }

    expect(secondLoggerLogs[0].status, 'info');
    expect(secondLoggerLogs[0].message, 'message on second logger');
    expect(secondLoggerLogs[0].log['second-logger-attribute'], 'second-value');
    expect(secondLoggerLogs[0].log['logger-attribute1'], isNull);
    expect(secondLoggerLogs[0].log['logger-attribute2'], isNull);
    expect(secondLoggerLogs[0].log['global-attribute'], 'global value');
    expect(getNestedProperty<String>('logger.name', secondLoggerLogs[1].log),
        'second_logger');

    expect(secondLoggerLogs[1].status, 'warn');
    expect(secondLoggerLogs[1].message, 'Warning: this error occurred');
    expect(secondLoggerLogs[1].log['second-logger-attribute'], 'second-value');
    expect(secondLoggerLogs[1].log['logger-attribute1'], isNull);
    expect(secondLoggerLogs[1].log['logger-attribute2'], isNull);
    expect(secondLoggerLogs[1].log['global-attribute'], 'global value');
    expect(secondLoggerLogs[1].errorMessage, 'Error Message');
    expect(secondLoggerLogs[1].errorStack, isNotNull);
    expect(secondLoggerLogs[1].errorFingerprint, 'custom-fingerprint');
    expect(getNestedProperty<String>('logger.name', secondLoggerLogs[1].log),
        'second_logger');

    expect(secondLoggerLogs[2].status, 'info');
    expect(secondLoggerLogs[2].message, 'Test local attribute override');
    expect(secondLoggerLogs[2].log['second-logger-attribute'], 'second-value');
    expect(secondLoggerLogs[2].log['global-attribute'], 'overridden');
    expect(getNestedProperty<String>('logger.name', secondLoggerLogs[1].log),
        'second_logger');

    for (final log in logs) {
      expect(log.serviceName,
          equalsIgnoringCase('com.datadoghq.flutter.integration'));
      expect(log.userId, 'bits');
      expect(log.userName, 'Bits Dawoof');
      expect(log.userEmail, 'bits@datadoghq.com');
      expect(log.getUserProperty('type'), 'dog');
      expect(log.getUserProperty('department'), 'data');

      if (!kIsWeb) {
        if (Platform.isIOS) {
          expect(log.applicationVersion, '1.2.3-555');
        }
        expect(log.threadName, 'main');
      }

      // Verify expected tags
      expect(log.tagValues.contains('env:prod'), isTrue);
      expect(log.tagValues.contains('version:1.2.3-555'), isTrue);
      expect(log.tagValues.contains('variant:integration'), isTrue);
    }
  });
}
