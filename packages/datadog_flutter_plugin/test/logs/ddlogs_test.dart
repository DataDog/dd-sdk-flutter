// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:async';
import 'dart:math';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/src/internal_logger.dart';
import 'package:datadog_flutter_plugin/src/logs/ddlogs_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockInternalLogger extends Mock implements InternalLogger {}

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockDdLogsPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DdLogsPlatform {}

void main() {
  late MockDatadogSdk mockCore;
  late MockInternalLogger mockInternalLogger;
  late MockDdLogsPlatform mockPlatform;
  late DatadogLogging ddLogs;

  setUp(() async {
    registerFallbackValue(LogLevel.info);
    registerFallbackValue(DatadogLoggingConfiguration());
    registerFallbackValue(DatadogLoggerConfiguration());
    registerFallbackValue(DatadogSdk.instance);

    mockPlatform = MockDdLogsPlatform();
    DdLogsPlatform.instance = mockPlatform;
    when(() => mockPlatform.enable(any(), any()))
        .thenAnswer((_) => Future.value());
    when(() => mockPlatform.createLogger(any(), any()))
        .thenAnswer((_) => Future.value());
    when(() => mockPlatform.destroyLogger(any()))
        .thenAnswer((_) => Future.value());

    mockInternalLogger = MockInternalLogger();
    mockCore = MockDatadogSdk();
    when(() => mockCore.internalLogger).thenReturn(mockInternalLogger);

    final config = DatadogLoggingConfiguration();
    ddLogs = (await DatadogLogging.enable(mockCore, config))!;
  });

  group('basic logger tests', () {
    late DatadogLogger ddLog;

    setUp(() async {
      when(() =>
              mockPlatform.log(any(), any(), any(), any(), any(), any(), any()))
          .thenAnswer((invocation) => Future<void>.value());

      final logConfig =
          DatadogLoggerConfiguration(remoteLogThreshold: LogLevel.debug);
      ddLog = ddLogs.createLogger(logConfig);
    });

    test('debug logs pass to platform', () async {
      ddLog.debug('debug message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLog.loggerHandle, LogLevel.debug,
          'debug message', null, null, null, {'attribute': 'value'}));
    });

    test('debug info pass to platform', () async {
      ddLog.info('info message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLog.loggerHandle, LogLevel.info,
          'info message', null, null, null, {'attribute': 'value'}));
    });

    test('debug warn pass to platform', () async {
      ddLog.warn('warn message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLog.loggerHandle, LogLevel.warning,
          'warn message', null, null, null, {'attribute': 'value'}));
    });

    test('error logs pass to platform', () async {
      ddLog.error('error message', attributes: {'attribute': 'value'});

      verify(() => mockPlatform.log(ddLog.loggerHandle, LogLevel.error,
          'error message', null, null, null, {'attribute': 'value'}));
    });

    test('addAttribute argumentError sent to logger', () async {
      when(() => mockPlatform.addAttribute(any(), any(), any()))
          .thenThrow(ArgumentError());
      ddLog.addAttribute('My key', 'Any Value');

      verify(
          () => mockInternalLogger.warn(any(that: contains('ArgumentError'))));
    });
  });

  group('configuration tests', () {
    test('sampleRate is clamped to 0..100', () {
      final lowConfiguration =
          DatadogLoggerConfiguration(remoteSampleRate: -12.2);

      final highConfiguration =
          DatadogLoggerConfiguration(remoteSampleRate: 123.5);

      expect(lowConfiguration.remoteSampleRate, 0);
      expect(highConfiguration.remoteSampleRate, 100);
    });

    test('logging configuration is encoded correctly', () {
      final customEndpoint = randomString();
      final loggingConfiguration = DatadogLoggingConfiguration(
        customEndpoint: customEndpoint,
        eventMapper: (event) => event,
      );

      final encoded = loggingConfiguration.encode();
      expect(encoded['customEndpoint'], customEndpoint);
      expect(encoded['attachLogMapper'], true);
    });

    test('logger configuraiton is encoded correctly', () {
      final service = randomString();
      final remoteLogThreshold = LogLevel.values.randomElement();
      final bundleWithRum = randomBool();
      final bundleWithTrace = randomBool();
      final networkInfoEnabled = randomBool();
      final logConfiguraiton = DatadogLoggerConfiguration(
        service: service,
        remoteLogThreshold: remoteLogThreshold,
        bundleWithRumEnabled: bundleWithRum,
        bundleWithTraceEnabled: bundleWithTrace,
        networkInfoEnabled: networkInfoEnabled,
        remoteSampleRate: 20.0,
      );

      final encoded = logConfiguraiton.encode();
      expect(encoded['service'], service);
      expect(encoded['remoteLogThreshold'], remoteLogThreshold.toString());
      expect(encoded['bundleWithRumEnabled'], bundleWithRum);
      expect(encoded['bundleWithTraceEnabled'], bundleWithTrace);
      expect(encoded['networkInfoEnabled'], networkInfoEnabled);
      expect(encoded['remoteSampleRate'], 20.0);
    });
  });

  test('logger samples at configured rate', () async {
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

    final config = DatadogLoggingConfiguration();
    final ddLogs = (await DatadogLogging.enable(mockCore, config))!;
    final logConfig = DatadogLoggerConfiguration(
      remoteLogThreshold: LogLevel.debug,
      remoteSampleRate: sampleRate,
    );
    final logger = ddLogs.createLogger(logConfig);
    for (var i = 0; i < 1000; ++i) {
      logger.info(randomString());
    }

    final targetLogCount = 1000 * (sampleRate / 100);
    // Should be target count with a 10% margin of error
    expect(logCount, greaterThan(targetLogCount * .9));
    expect(logCount, lessThan(targetLogCount * 1.1));
  });

  group('threshold tests', () {
    late DatadogLogger logger;

    setUp(() {
      when(() =>
              mockPlatform.log(any(), any(), any(), any(), any(), any(), any()))
          .thenAnswer((invocation) => Future<void>.value());
      final config =
          DatadogLoggerConfiguration(remoteLogThreshold: LogLevel.debug);
      logger = ddLogs.createLogger(config);
    });

    test('threshold set to verbose always calls platform', () async {
      final config =
          DatadogLoggerConfiguration(remoteLogThreshold: LogLevel.debug);
      logger = ddLogs.createLogger(config);

      logger.debug('Debug message');
      logger.info('Info message');
      logger.warn('Warn message');
      logger.error('Error message');

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
          DatadogLoggerConfiguration(remoteLogThreshold: LogLevel.warning);
      logger = ddLogs.createLogger(config);

      logger.debug('Debug message');
      logger.info('Info message');
      logger.warn('Warn message');
      logger.error('Error message');

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

    test('sample set to none does not call platform', () async {
      final config = DatadogLoggerConfiguration(remoteSampleRate: 0.0);
      logger = ddLogs.createLogger(config);

      logger.debug('Debug message');
      logger.info('Info message');
      logger.warn('Warn message');
      logger.error('Error message');

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

  if (kDebugMode) {
    group('console printing', () {
      setUp(() {
        when(() => mockPlatform.log(
                any(), any(), any(), any(), any(), any(), any()))
            .thenAnswer((invocation) => Future<void>.value());
      });

      var printLog = <String>[];
      void Function() overridePrint(void Function() testFn) => () {
            var spec = ZoneSpecification(print: (_, __, ___, String msg) {
              // Add to log instead of printing to stdout
              printLog.add(msg);
            });
            printLog.clear();
            return Zone.current.fork(specification: spec).run<void>(testFn);
          };

      test('simpleConsolePrint logs to print by default', overridePrint(() {
        final config =
            DatadogLoggerConfiguration(remoteLogThreshold: LogLevel.warning);
        final logger = ddLogs.createLogger(config);

        logger.debug('Debug message');
        logger.info('Info message');
        logger.warn('Warn message');
        logger.error('Error message');

        expect(printLog.length, 4);
        expect(printLog, [
          '[debug] Debug message',
          '[info] Info message',
          '[warning] Warn message',
          '[error] Error message',
        ]);
      }));

      test('simpleConsolePrintForLevel logs to print by default',
          overridePrint(() async {
        final config = DatadogLoggerConfiguration(
          remoteLogThreshold: LogLevel.warning,
          customConsoleLogFunction: simpleConsolePrintForLevel(LogLevel.debug),
        );
        final logger = ddLogs.createLogger(config);

        logger.debug('Debug message');
        logger.info('Info message');
        logger.warn('Warn message');
        logger.error('Error message');

        expect(printLog.length, 4);
        expect(printLog, [
          '[debug] Debug message',
          '[info] Info message',
          '[warning] Warn message',
          '[error] Error message',
        ]);
      }));

      test('simpleConsolePrintForLevel filters to correct level',
          overridePrint(() {
        final config = DatadogLoggerConfiguration(
          remoteLogThreshold: LogLevel.warning,
          customConsoleLogFunction:
              simpleConsolePrintForLevel(LogLevel.warning),
        );
        final logger = ddLogs.createLogger(config);

        logger.debug('Debug message');
        logger.info('Info message');
        logger.warn('Warn message');
        logger.error('Error message');

        expect(printLog.length, 2);
        expect(printLog, [
          '[warning] Warn message',
          '[error] Error message',
        ]);
      }));
    });
  }
}
