// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:math';

import 'package:datadog_common_test/datadog_common_test.dart';
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
  late TestLogger internalLogger;
  late MockDdLogsPlatform mockPlatform;

  setUp(() {
    registerFallbackValue(LogLevel.info);
    internalLogger = TestLogger();
    mockPlatform = MockDdLogsPlatform();
    DdLogsPlatform.instance = mockPlatform;
  });

  group('basic logger tests', () {
    late DdLogs ddLogs;

    setUp(() {
      when(() =>
              mockPlatform.log(any(), any(), any(), any(), any(), any(), any()))
          .thenAnswer((invocation) => Future<void>.value());

      final config =
          LoggingConfiguration(datadogReportingThreshold: Verbosity.verbose);
      ddLogs = DdLogs(internalLogger, config);
    });

    test('debug logs pass to platform', () async {
      ddLogs.debug('debug message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLogs.loggerHandle, LogLevel.debug,
          'debug message', null, null, null, {'attribute': 'value'}));
    });

    test('debug info pass to platform', () async {
      ddLogs.info('info message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLogs.loggerHandle, LogLevel.info,
          'info message', null, null, null, {'attribute': 'value'}));
    });

    test('debug warn pass to platform', () async {
      ddLogs.warn('warn message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLogs.loggerHandle, LogLevel.warning,
          'warn message', null, null, null, {'attribute': 'value'}));
    });

    test('error logs pass to platform', () async {
      ddLogs.error('error message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLogs.loggerHandle, LogLevel.error,
          'error message', null, null, null, {'attribute': 'value'}));
    });

    test('addAttribute argumentError sent to logger', () async {
      when(() => mockPlatform.addAttribute(any(), any(), any()))
          .thenThrow(ArgumentError());
      ddLogs.addAttribute('My key', 'Any Value');

      assert(internalLogger.logs.isNotEmpty);
    });
  });

  group('configuration tests', () {
    test('sampleRate is clamped to 0..100', () {
      final lowConfiguration = LoggingConfiguration(sampleRate: -12.2);

      final highConfiguration = LoggingConfiguration(sampleRate: 123.5);

      expect(lowConfiguration.sampleRate, 0);
      expect(highConfiguration.sampleRate, 100);
    });
  });

  test('logger samples at configured rate', () {
    final random = Random();
    // Sample rate between 10% and 90%
    final sampleRate = random.nextDouble() * 80 + 10;
    int logCount = 0;
    when(() =>
            mockPlatform.log(any(), any(), any(), any(), any(), any(), any()))
        .thenAnswer((invocation) {
      logCount++;
      return Future.value();
    });

    final configuration = LoggingConfiguration(sampleRate: sampleRate);
    final logger = DdLogs(internalLogger, configuration);
    for (var i = 0; i < 1000; ++i) {
      logger.info(randomString());
    }

    final targetLogCount = 1000 * (sampleRate / 100);
    // Should be target count with a 10% margin of error
    expect(logCount, greaterThan(targetLogCount * .9));
    expect(logCount, lessThan(targetLogCount * 1.1));
  });

  group('threshold tests', () {
    late DdLogs ddLogs;

    setUp(() {
      when(() =>
              mockPlatform.log(any(), any(), any(), any(), any(), any(), any()))
          .thenAnswer((invocation) => Future<void>.value());
      final config =
          LoggingConfiguration(datadogReportingThreshold: Verbosity.verbose);
      ddLogs = DdLogs(internalLogger, config);
    });

    test('threshold set to verbose always calls platform', () async {
      final config =
          LoggingConfiguration(datadogReportingThreshold: Verbosity.verbose);
      ddLogs = DdLogs(internalLogger, config);

      ddLogs.debug('Debug message');
      ddLogs.info('Info message');
      ddLogs.warn('Warn message');
      ddLogs.error('Error message');

      for (var level in [
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warning,
        LogLevel.error
      ]) {
        verify(() =>
            mockPlatform.log(any(), level, any(), null, null, null, any()));
      }
    });

    test('threshold set to middle sends call proper platform methods',
        () async {
      final config =
          LoggingConfiguration(datadogReportingThreshold: Verbosity.warn);
      ddLogs = DdLogs(internalLogger, config);

      ddLogs.debug('Debug message');
      ddLogs.info('Info message');
      ddLogs.warn('Warn message');
      ddLogs.error('Error message');

      for (var level in [
        LogLevel.debug,
        LogLevel.info,
      ]) {
        verifyNever(() =>
            mockPlatform.log(any(), level, any(), any(), any(), any(), any()));
      }

      for (var level in [
        LogLevel.warning,
        LogLevel.error,
      ]) {
        verify(() =>
            mockPlatform.log(any(), level, any(), null, null, null, any()));
      }
    });

    test('threshold set to none does not call platform', () async {
      final config =
          LoggingConfiguration(datadogReportingThreshold: Verbosity.none);
      ddLogs = DdLogs(internalLogger, config);

      ddLogs.debug('Debug message');
      ddLogs.info('Info message');
      ddLogs.warn('Warn message');
      ddLogs.error('Error message');

      for (var level in [
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warning,
        LogLevel.error
      ]) {
        verifyNever(() =>
            mockPlatform.log(any(), level, any(), any(), any(), any(), any()));
      }
    });
  });
}
