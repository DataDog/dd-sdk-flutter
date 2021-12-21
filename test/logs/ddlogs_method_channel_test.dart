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

  test('addAttribute passed to method channel', () async {
    await ddLogsPlatform.addAttribute('my_key', 'my_value');

    expect(log, <Matcher>[
      isMethodCall('addAttribute',
          arguments: {'key': 'my_key', 'value': 'my_value'})
    ]);
  });

  test('addAttributes passes complicated values to method channel', () async {
    await ddLogsPlatform.addAttribute('my_attribute', true);
    await ddLogsPlatform.addAttribute('my_attribute', {
      'int_value': 256,
      'bool_value': false,
      'double_value': 2.3,
      'string_value': 'test_value'
    });

    expect(log, <Matcher>[
      isMethodCall('addAttribute',
          arguments: {'key': 'my_attribute', 'value': true}),
      isMethodCall('addAttribute', arguments: {
        'key': 'my_attribute',
        'value': {
          'int_value': 256,
          'bool_value': false,
          'double_value': 2.3,
          'string_value': 'test_value',
        },
      })
    ]);
  });

  test('removeAttribute passes to method channel', () async {
    await ddLogsPlatform.removeAttribute('my_attribute');

    expect(log, <Matcher>[
      isMethodCall('removeAttribute', arguments: {
        'key': 'my_attribute',
      })
    ]);
  });

  test('addTag passes tag to method channel', () async {
    await ddLogsPlatform.addTag('my_tag');

    expect(log, <Matcher>[
      isMethodCall('addTag', arguments: {'tag': 'my_tag', 'value': null})
    ]);
  });

  test('addTag passes tag and value to method channel', () async {
    await ddLogsPlatform.addTag('my_tag', 'tag_value');

    expect(log, <Matcher>[
      isMethodCall('addTag', arguments: {'tag': 'my_tag', 'value': 'tag_value'})
    ]);
  });

  test('removeTag passes tag to method channel', () async {
    await ddLogsPlatform.removeTag('my_tag');

    expect(log, <Matcher>[
      isMethodCall('removeTag', arguments: {'tag': 'my_tag'}),
    ]);
  });

  test('removeTagWithKey passed to method channel', () async {
    await ddLogsPlatform.removeTagWithKey('my_tag');

    expect(log, <Matcher>[
      isMethodCall('removeTagWithKey', arguments: {'key': 'my_tag'})
    ]);
  });
}
