// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/src/internal_logger.dart';
import 'package:datadog_flutter_plugin/src/logs/ddlogs.dart';
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
    ddLogs = DdLogs(logger);
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
}
