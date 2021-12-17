// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import 'package:datadog_sdk/logs/ddlogs.dart';
import 'package:datadog_sdk/logs/ddlogs_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ddlogs_test.mocks.dart';

abstract class MixedDdLogsPlatform
    with MockPlatformInterfaceMixin
    implements DdLogsPlatform {}

@GenerateMocks([MixedDdLogsPlatform])
void main() {
  late DdLogs ddLogs;
  late MockMixedDdLogsPlatform fakePlatform;

  setUp(() {
    fakePlatform = MockMixedDdLogsPlatform();
    DdLogsPlatform.instance = fakePlatform;
    ddLogs = DdLogs();
  });

  test('debug logs pass to platform', () async {
    ddLogs.debug('debug message', {'attribute': 'value'});

    verify(fakePlatform.debug('debug message', {'attribute': 'value'}));
  });

  test('info logs pass to platform', () async {
    ddLogs.info('info message', {'attribute': 'value'});

    verify(fakePlatform.info('info message', {'attribute': 'value'}));
  });

  test('warn logs pass to platform', () async {
    ddLogs.warn('warn message', {'attribute': 'value'});

    verify(fakePlatform.warn('warn message', {'attribute': 'value'}));
  });

  test('error logs pass to platform', () async {
    ddLogs.error('error message', {'attribute': 'value'});

    verify(fakePlatform.error('error message', {'attribute': 'value'}));
  });
}
