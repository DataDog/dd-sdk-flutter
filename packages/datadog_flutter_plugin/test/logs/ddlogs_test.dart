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
      when(() => mockPlatform.debug(any(), any(), any()))
          .thenAnswer((invocation) => Future.value());
      when(() => mockPlatform.info(any(), any(), any()))
          .thenAnswer((invocation) => Future.value());
      when(() => mockPlatform.warn(any(), any(), any()))
          .thenAnswer((invocation) => Future.value());
      when(() => mockPlatform.error(any(), any(), any()))
          .thenAnswer((invocation) => Future.value());
      DdLogsPlatform.instance = mockPlatform;
      ddLogs = DdLogs(logger, Verbosity.verbose);
    });

    test('debug logs pass to platform', () async {
      ddLogs.debug('debug message', {'attribute': 'value'});

      verify(() => mockPlatform
          .debug(ddLogs.loggerHandle, 'debug message', {'attribute': 'value'}));
    });

    test('info logs pass to platform', () async {
      ddLogs.info('info message', {'attribute': 'value'});

      verify(() => mockPlatform
          .info(ddLogs.loggerHandle, 'info message', {'attribute': 'value'}));
    });

    test('warn logs pass to platform', () async {
      ddLogs.warn('warn message', {'attribute': 'value'});

      verify(() => mockPlatform
          .warn(ddLogs.loggerHandle, 'warn message', {'attribute': 'value'}));
    });

    test('error logs pass to platform', () async {
      ddLogs.error('error message', {'attribute': 'value'});

      verify(() => mockPlatform
          .error(ddLogs.loggerHandle, 'error message', {'attribute': 'value'}));
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
      when(() => mockPlatform.debug(any(), any(), any()))
          .thenAnswer((invocation) => Future.value());
      when(() => mockPlatform.info(any(), any(), any()))
          .thenAnswer((invocation) => Future.value());
      when(() => mockPlatform.warn(any(), any(), any()))
          .thenAnswer((invocation) => Future.value());
      when(() => mockPlatform.error(any(), any(), any()))
          .thenAnswer((invocation) => Future.value());
      DdLogsPlatform.instance = mockPlatform;
    });

    test('threshold set to verbose always calls platform', () async {
      ddLogs = DdLogs(logger, Verbosity.verbose);

      ddLogs.debug('Debug message');
      ddLogs.info('Info message');
      ddLogs.warn('Warn message');
      ddLogs.error('Error message');

      verify(() => mockPlatform.debug(any(), any()));
      verify(() => mockPlatform.info(any(), any()));
      verify(() => mockPlatform.warn(any(), any()));
      verify(() => mockPlatform.error(any(), any()));
    });

    test('threshold set to middle sends call proper platform methods',
        () async {
      ddLogs = DdLogs(logger, Verbosity.warn);

      ddLogs.debug('Debug message');
      ddLogs.info('Info message');
      ddLogs.warn('Warn message');
      ddLogs.error('Error message');

      verifyNever(() => mockPlatform.debug(any(), any()));
      verifyNever(() => mockPlatform.info(any(), any()));
      verify(() => mockPlatform.warn(any(), any()));
      verify(() => mockPlatform.error(any(), any()));
    });

    test('threshold set to none does not call platform', () async {
      ddLogs = DdLogs(logger, Verbosity.none);

      ddLogs.debug('Debug message');
      ddLogs.info('Info message');
      ddLogs.warn('Warn message');
      ddLogs.error('Error message');

      verifyNever(() => mockPlatform.debug(any(), any()));
      verifyNever(() => mockPlatform.info(any(), any()));
      verifyNever(() => mockPlatform.warn(any(), any()));
      verifyNever(() => mockPlatform.error(any(), any()));
    });
  });
}
