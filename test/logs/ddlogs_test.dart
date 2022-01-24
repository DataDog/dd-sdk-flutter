// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:datadog_sdk/src/internal_logger.dart';
import 'package:datadog_sdk/src/logs/ddlogs.dart';
import 'package:datadog_sdk/src/logs/ddlogs_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ddlogs_test.mocks.dart';

abstract class MixedDdLogsPlatform
    with MockPlatformInterfaceMixin
    implements DdLogsPlatform {}

class TestLogger extends InternalLogger {
  final logs = <String>[];

  @override
  void log(Verbosity verbosity, String log) {
    logs.add(log);
  }
}

@GenerateMocks([MixedDdLogsPlatform])
void main() {
  late TestLogger logger;
  late DdLogs ddLogs;
  late MockMixedDdLogsPlatform fakePlatform;

  setUp(() {
    logger = TestLogger();
    fakePlatform = MockMixedDdLogsPlatform();
    DdLogsPlatform.instance = fakePlatform;
    ddLogs = DdLogs(logger);
  });

  test('debug logs pass to platform', () async {
    await ddLogs.debug('debug message', {'attribute': 'value'});

    verify(fakePlatform.debug('debug message', {'attribute': 'value'}));
  });

  test('info logs pass to platform', () async {
    await ddLogs.info('info message', {'attribute': 'value'});

    verify(fakePlatform.info('info message', {'attribute': 'value'}));
  });

  test('warn logs pass to platform', () async {
    await ddLogs.warn('warn message', {'attribute': 'value'});

    verify(fakePlatform.warn('warn message', {'attribute': 'value'}));
  });

  test('error logs pass to platform', () async {
    await ddLogs.error('error message', {'attribute': 'value'});

    verify(fakePlatform.error('error message', {'attribute': 'value'}));
  });

  test('addAttribute argumentError sent to logger', () async {
    when(fakePlatform.addAttribute(any, any)).thenThrow(ArgumentError());
    await ddLogs.addAttribute('My key', 'Any Value');

    assert(logger.logs.isNotEmpty);
  });
}
