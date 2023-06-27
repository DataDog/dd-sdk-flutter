// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/src/internal_logger.dart';
import 'package:datadog_flutter_plugin/src/logs/ddlogs_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDdLogsPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DdLogsPlatform {}

class TestLogger extends InternalLogger {
  final logs = <String>[];

  @override
  void log(Verbosity verbosity, String log) {
    logs.add(log);
  }
}

void main() {
  late TestLogger logger;
  late DdLogs ddLogs;
  late MockDdLogsPlatform mockPlatform;

  group('basic logger tests', () {
    setUp(() {
      logger = TestLogger();
      mockPlatform = MockDdLogsPlatform();
      registerFallbackValue(LogLevel.info);
      when(() =>
              mockPlatform.log(any(), any(), any(), any(), any(), any(), any()))
          .thenAnswer((invocation) => Future<void>.value());
      DdLogsPlatform.instance = mockPlatform;
      ddLogs = DdLogs(logger, Verbosity.verbose);
    });

    test('debug logs pass to platform', () async {
      ddLogs.debug('debug message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLogs.loggerHandle, LogLevel.debug,
          'debug message', null, null, null, {'attribute': 'value'}));
    });

    test('info logs pass to platform', () async {
      ddLogs.info('info message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLogs.loggerHandle, LogLevel.info,
          'info message', null, null, null, {'attribute': 'value'}));
    });

    test('notice logs pass to platform', () async {
      ddLogs.notice('notice message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLogs.loggerHandle, LogLevel.notice,
          'notice message', null, null, null, {'attribute': 'value'}));
    });

    test('warn logs pass to platform', () async {
      ddLogs.warn('warn message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLogs.loggerHandle, LogLevel.warning,
          'warn message', null, null, null, {'attribute': 'value'}));
    });

    test('error logs pass to platform', () async {
      ddLogs.error('error message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLogs.loggerHandle, LogLevel.error,
          'error message', null, null, null, {'attribute': 'value'}));
    });

    test('critical logs pass to platform', () async {
      ddLogs.critical('critical message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLogs.loggerHandle, LogLevel.critical,
          'critical message', null, null, null, {'attribute': 'value'}));
    });

    test('alert logs pass to platform', () async {
      ddLogs.alert('alert message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLogs.loggerHandle, LogLevel.alert,
          'alert message', null, null, null, {'attribute': 'value'}));
    });

    test('emergency logs pass to platform', () async {
      ddLogs.emergency('emergency message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLogs.loggerHandle, LogLevel.emergency,
          'emergency message', null, null, null, {'attribute': 'value'}));
    });

    test('addAttribute argumentError sent to logger', () async {
      when(() => mockPlatform.addAttribute(any(), any(), any()))
          .thenThrow(ArgumentError());
      ddLogs.addAttribute('My key', 'Any Value');

      assert(logger.logs.isNotEmpty);
    });
  });

  group('threshold tests', () {
    setUp(() {
      logger = TestLogger();
      mockPlatform = MockDdLogsPlatform();
      registerFallbackValue(LogLevel.info);
      when(() =>
              mockPlatform.log(any(), any(), any(), any(), any(), any(), any()))
          .thenAnswer((invocation) => Future<void>.value());
      DdLogsPlatform.instance = mockPlatform;
    });

    test('threshold set to verbose always calls platform', () async {
      ddLogs = DdLogs(logger, Verbosity.verbose);

      ddLogs.debug('Debug message');
      ddLogs.info('Info message');
      ddLogs.notice('Notice message');
      ddLogs.warn('Warn message');
      ddLogs.error('Error message');
      ddLogs.critical('Critical message');
      ddLogs.alert('Alert message');
      ddLogs.emergency('Emergency message');

      for (var level in LogLevel.values) {
        verify(() =>
            mockPlatform.log(any(), level, any(), null, null, null, any()));
      }
    });

    test('threshold set to middle sends call proper platform methods',
        () async {
      ddLogs = DdLogs(logger, Verbosity.warn);

      ddLogs.debug('Debug message');
      ddLogs.info('Info message');
      ddLogs.notice('Notice message');
      ddLogs.warn('Warn message');
      ddLogs.error('Error message');
      ddLogs.critical('Critical message');
      ddLogs.alert('Alert message');
      ddLogs.emergency('Emergency message');

      for (var level in [LogLevel.debug, LogLevel.info, LogLevel.notice]) {
        verifyNever(() =>
            mockPlatform.log(any(), level, any(), any(), any(), any(), any()));
      }

      for (var level in [
        LogLevel.warning,
        LogLevel.error,
        LogLevel.critical,
        LogLevel.alert,
        LogLevel.emergency
      ]) {
        verify(() =>
            mockPlatform.log(any(), level, any(), null, null, null, any()));
      }
    });

    test('threshold set to none does not call platform', () async {
      ddLogs = DdLogs(logger, Verbosity.none);

      ddLogs.debug('Debug message');
      ddLogs.info('Info message');
      ddLogs.notice('Notice message');
      ddLogs.warn('Warn message');
      ddLogs.error('Error message');
      ddLogs.critical('Critical message');
      ddLogs.alert('Alert message');
      ddLogs.emergency('Emergency message');

      for (var level in LogLevel.values) {
        verifyNever(() =>
            mockPlatform.log(any(), level, any(), any(), any(), any(), any()));
      }
    });
  });
}
