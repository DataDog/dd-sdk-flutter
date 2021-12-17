// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import 'package:datadog_sdk/logs/ddlogs_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DdLogsMethodChannel ddLogsPlatform;
  final List<MethodCall> log = [];

  setUp(() {
    ddLogsPlatform = DdLogsMethodChannel();
    ddLogsPlatform.methodChannel.setMockMethodCallHandler((call) {
      log.add(call);
      return null;
    });
  });

  tearDown(() {
    log.clear();
  });

  test('debug logs passed to method channel', () async {
    await ddLogsPlatform.debug('debug message', {'attribute': 'value'});

    expect(log, <Matcher>[
      isMethodCall('debug', arguments: {
        'message': 'debug message',
        'context': {'attribute': 'value'}
      })
    ]);
  });

  test('info logs passed to method channel', () async {
    await ddLogsPlatform.info('info message', {'attribute': 'value'});

    expect(log, <Matcher>[
      isMethodCall('info', arguments: {
        'message': 'info message',
        'context': {'attribute': 'value'}
      })
    ]);
  });

  test('warn logs passed to method channel', () async {
    await ddLogsPlatform.warn('warn message', {'attribute': 'value'});

    expect(log, <Matcher>[
      isMethodCall('warn', arguments: {
        'message': 'warn message',
        'context': {'attribute': 'value'}
      })
    ]);
  });

  test('error logs passed to method channel', () async {
    await ddLogsPlatform.error('error message', {'attribute': 'value'});

    expect(log, <Matcher>[
      isMethodCall('error', arguments: {
        'message': 'error message',
        'context': {'attribute': 'value'}
      })
    ]);
  });
}
