// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_flutter_plugin/src/logs/ddlogs_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DdLogsMethodChannel ddLogsPlatform;
  final List<MethodCall> log = [];

  setUp(() {
    ddLogsPlatform = DdLogsMethodChannel();
    ambiguate(TestDefaultBinaryMessengerBinding.instance)
        ?.defaultBinaryMessenger
        .setMockMethodCallHandler(ddLogsPlatform.methodChannel, (message) {
      log.add(message);
      return null;
    });
  });

  tearDown(() {
    log.clear();
  });

  test('create logger passed to method channel', () async {
    final config = DatadogLoggerConfiguration(name: 'loggerName');
    await ddLogsPlatform.createLogger('uuid', config);

    expect(log, <Matcher>[
      isMethodCall('createLogger', arguments: {
        'loggerHandle': 'uuid',
        'configuration': config.encode(),
      })
    ]);
  });

  test('log messages passed to method channel', () async {
    for (final logLevel in LogLevel.values) {
      await ddLogsPlatform.log('uuid', logLevel, '$logLevel message', null,
          null, null, {'attribute': 'value'});
    }

    expect(log, <Matcher>[
      for (final logLevel in LogLevel.values)
        isMethodCall('log', arguments: {
          'loggerHandle': 'uuid',
          'logLevel': logLevel.toString(),
          'message': '$logLevel message',
          'errorMessage': null,
          'errorKind': null,
          'stackTrace': null,
          'context': {
            'attribute': 'value',
          }
        })
    ]);
  });

  test('log messages passed with error passed to method channel', () async {
    final st = StackTrace.current;
    for (final logLevel in LogLevel.values) {
      await ddLogsPlatform.log('uuid', logLevel, '$logLevel message',
          '$logLevel error message', 'error_type', st, {'attribute': 'value'});
    }

    expect(log, <Matcher>[
      for (final logLevel in LogLevel.values)
        isMethodCall('log', arguments: {
          'loggerHandle': 'uuid',
          'logLevel': logLevel.toString(),
          'message': '$logLevel message',
          'errorMessage': '$logLevel error message',
          'errorKind': 'error_type',
          'stackTrace': st.toString(),
          'context': {
            'error.source_type': 'flutter',
            'attribute': 'value',
          }
        })
    ]);
  });

  test('log messages without stack trace do not add source_type', () async {
    for (final logLevel in LogLevel.values) {
      await ddLogsPlatform.log(
          'uuid',
          logLevel,
          '$logLevel message',
          '$logLevel error message',
          'error_type',
          null,
          {'attribute': 'value'});
    }

    expect(log, <Matcher>[
      for (final logLevel in LogLevel.values)
        isMethodCall('log', arguments: {
          'loggerHandle': 'uuid',
          'logLevel': logLevel.toString(),
          'message': '$logLevel message',
          'errorMessage': '$logLevel error message',
          'errorKind': 'error_type',
          'stackTrace': null,
          'context': {
            'attribute': 'value',
          }
        })
    ]);
  });

  test('addAttribute passed to method channel', () async {
    await ddLogsPlatform.addAttribute('uuid', 'my_key', 'my_value');

    expect(log, <Matcher>[
      isMethodCall('addAttribute', arguments: {
        'loggerHandle': 'uuid',
        'key': 'my_key',
        'value': 'my_value',
      })
    ]);
  });

  test('addAttributes passes complicated values to method channel', () async {
    await ddLogsPlatform.addAttribute('uuid', 'my_attribute', true);
    await ddLogsPlatform.addAttribute('uuid', 'my_attribute', {
      'int_value': 256,
      'bool_value': false,
      'double_value': 2.3,
      'string_value': 'test_value'
    });

    expect(log, <Matcher>[
      isMethodCall('addAttribute', arguments: {
        'loggerHandle': 'uuid',
        'key': 'my_attribute',
        'value': true,
      }),
      isMethodCall('addAttribute', arguments: {
        'loggerHandle': 'uuid',
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
    await ddLogsPlatform.removeAttribute('uuid', 'my_attribute');

    expect(log, <Matcher>[
      isMethodCall('removeAttribute', arguments: {
        'loggerHandle': 'uuid',
        'key': 'my_attribute',
      })
    ]);
  });

  test('addTag passes tag to method channel', () async {
    await ddLogsPlatform.addTag('uuid', 'my_tag');

    expect(log, <Matcher>[
      isMethodCall('addTag', arguments: {
        'loggerHandle': 'uuid',
        'tag': 'my_tag',
        'value': null,
      })
    ]);
  });

  test('addTag passes tag and value to method channel', () async {
    await ddLogsPlatform.addTag('uuid', 'my_tag', 'tag_value');

    expect(log, <Matcher>[
      isMethodCall('addTag', arguments: {
        'loggerHandle': 'uuid',
        'tag': 'my_tag',
        'value': 'tag_value',
      })
    ]);
  });

  test('removeTag passes tag to method channel', () async {
    await ddLogsPlatform.removeTag('uuid', 'my_tag');

    expect(log, <Matcher>[
      isMethodCall('removeTag', arguments: {
        'loggerHandle': 'uuid',
        'tag': 'my_tag',
      }),
    ]);
  });

  test('removeTagWithKey passed to method channel', () async {
    await ddLogsPlatform.removeTagWithKey('uuid', 'my_tag');

    expect(log, <Matcher>[
      isMethodCall('removeTagWithKey', arguments: {
        'loggerHandle': 'uuid',
        'key': 'my_tag',
      })
    ]);
  });
}
