// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:datadog_sdk/src/internal_logger.dart';
import 'package:datadog_sdk/src/traces/ddtraces.dart';
import 'package:datadog_sdk/src/traces/ddtraces_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DdTracesMethodChannel ddTracesPlatform;
  late InternalLogger ddLogger;
  final List<MethodCall> log = [];

  setUp(() {
    ddTracesPlatform = DdTracesMethodChannel();
    ddTracesPlatform.methodChannel.setMockMethodCallHandler((call) async {
      log.add(call);
      switch (call.method) {
        case 'startRootSpan':
          return true;
        case 'startSpan':
          return true;
        case 'getTracePropagationHeaders':
          return {'header-1': 'value-1', 'header-2': 'value-2'};
      }
      return null;
    });
    ddLogger = InternalLogger();
  });

  tearDown(() {
    log.clear();
  });

  test('all calls with bad span do not call platform', () async {
    var badSpan = DdSpan(ddTracesPlatform, systemTimeProvider, 0, ddLogger);
    badSpan.setActive();
    badSpan.setTag('Test Key', 'Test value');
    badSpan.setBaggageItem('Baggage Key', 'Baggage value');
    badSpan.setError(Exception());
    badSpan.setErrorInfo('Kind', 'Message', null);
    badSpan.finish();

    expect(log.length, 0);
  });

  test('start root span calls to platform', () async {
    var startTime = DateTime.now();
    final success = await ddTracesPlatform.startRootSpan(
        1, 'Root Operation', null, {'testTag': 'testValue'}, startTime);

    expect(success, isTrue);
    expect(log, <Matcher>[
      isMethodCall('startRootSpan', arguments: {
        'spanHandle': 1,
        'operationName': 'Root Operation',
        'resourceName': null,
        'tags': {'testTag': 'testValue'},
        'startTime': startTime.microsecondsSinceEpoch
      })
    ]);
  });

  test('start span calls to platform', () async {
    var startTime = DateTime.now();
    final success = await ddTracesPlatform.startSpan(
        3, 'Operation', null, null, {'testTag': 'testValue'}, startTime);

    expect(success, isTrue);
    expect(log, <Matcher>[
      isMethodCall('startSpan', arguments: {
        'spanHandle': 3,
        'operationName': 'Operation',
        'parentSpan': null,
        'resourceName': null,
        'tags': {'testTag': 'testValue'},
        'startTime': startTime.microsecondsSinceEpoch
      })
    ]);
  });

  test('start span passes parent handle', () async {
    var startTime = DateTime.now();
    final rootSpan = DdSpan(ddTracesPlatform, systemTimeProvider, 8, ddLogger);
    final childSuccess = await ddTracesPlatform.startSpan(
        10, 'Child operation', rootSpan, null, null, startTime);

    expect(childSuccess, isTrue);
    expect(log, <Matcher>[
      isMethodCall('startSpan', arguments: {
        'spanHandle': 10,
        'operationName': 'Child operation',
        'resourceName': null,
        'parentSpan': 8,
        'tags': null,
        'startTime': startTime.microsecondsSinceEpoch,
      }),
    ]);
  });

  test('start span converts milliseconds since epoch', () async {
    var startTime = DateTime.now().toUtc();
    await ddTracesPlatform.startSpan(
        8, 'Operation', null, null, null, startTime);

    expect(log, [
      isMethodCall('startSpan', arguments: {
        'spanHandle': 8,
        'operationName': 'Operation',
        'parentSpan': null,
        'resourceName': null,
        'tags': null,
        'startTime': startTime.microsecondsSinceEpoch,
      })
    ]);
  });

  test('start span converts to microseconds', () async {
    var startTime = DateTime.now();
    await ddTracesPlatform.startSpan(
        431, 'Operation', null, null, null, startTime);

    expect(log, [
      isMethodCall('startSpan', arguments: {
        'spanHandle': 431,
        'operationName': 'Operation',
        'parentSpan': null,
        'resourceName': null,
        'tags': null,
        'startTime': startTime.microsecondsSinceEpoch,
      })
    ]);
  });

  test('start span passes resource name', () async {
    var startTime = DateTime.now();
    await ddTracesPlatform.startSpan(
        555, 'Operation', null, 'mock resource name', null, startTime);

    expect(log, [
      isMethodCall('startSpan', arguments: {
        'spanHandle': 555,
        'operationName': 'Operation',
        'parentSpan': null,
        'resourceName': 'mock resource name',
        'tags': null,
        'startTime': startTime.microsecondsSinceEpoch,
      })
    ]);
  });

  test('getTracePropagationHeaders calls platform', () async {
    final span = DdSpan(ddTracesPlatform, systemTimeProvider, 8, ddLogger);
    final headers = await ddTracesPlatform.getTracePropagationHeaders(span);
    expect(log, [
      isMethodCall('getTracePropagationHeaders', arguments: {
        'spanHandle': span.handle,
      }),
    ]);
    expect(headers, {'header-1': 'value-1', 'header-2': 'value-2'});
  });

  test('finish span calls platform', () async {
    final endTime = DateTime.now();
    await ddTracesPlatform.spanFinish(12, endTime);

    expect(
        log[0],
        isMethodCall('span.finish', arguments: {
          'spanHandle': 12,
          'finishTime': endTime.microsecondsSinceEpoch,
        }));
  });

  test('finish span invalidates handle', () async {
    final span = DdSpan(ddTracesPlatform, systemTimeProvider, 8, ddLogger);
    span.finish();

    expect(span.handle, lessThanOrEqualTo(0));
  });

  test('setTag on span calls to platform', () async {
    final span = DdSpan(ddTracesPlatform, systemTimeProvider, 12, ddLogger);
    span.setTag('my tag', 'tag value');

    expect(
      log[0],
      isMethodCall('span.setTag', arguments: {
        'spanHandle': span.handle,
        'key': 'my tag',
        'value': 'tag value',
      }),
    );
  });

  test('setBaggageItem calls to platform', () async {
    final span = DdSpan(ddTracesPlatform, systemTimeProvider, 12, ddLogger);
    span.setBaggageItem('my key', 'my value');

    expect(
        log[0],
        isMethodCall('span.setBaggageItem', arguments: {
          'spanHandle': span.handle,
          'key': 'my key',
          'value': 'my value'
        }));
  });

  test('setTag calls to platform', () async {
    final span = DdSpan(ddTracesPlatform, systemTimeProvider, 12, ddLogger);
    span.setTag('my key', 'my value');

    expect(
        log[0],
        isMethodCall('span.setTag', arguments: {
          'spanHandle': span.handle,
          'key': 'my key',
          'value': 'my value'
        }));
  });

  test('setError on span calls to platform', () async {
    final span = DdSpan(ddTracesPlatform, systemTimeProvider, 12, ddLogger);
    StackTrace? caughtStackTrace;
    Exception? caughtException;

    try {
      throw Exception('Test Throw Exception');
    } on Exception catch (e, s) {
      caughtException = e;
      caughtStackTrace = s;
      span.setError(e, s);
    }

    expect(
      log[0],
      isMethodCall('span.setError', arguments: {
        'spanHandle': span.handle,
        'kind': caughtException.runtimeType.toString(),
        'message': caughtException.toString(),
        'stackTrace': caughtStackTrace.toString(),
      }),
    );
  });

  test('setErrorInfo on span calls to platform', () async {
    final span = DdSpan(ddTracesPlatform, systemTimeProvider, 12, ddLogger);
    span.setErrorInfo('Generic Error', 'This was my fault', null);

    var spanCall = log[0];

    expect(spanCall.method, 'span.setError');
    expect(spanCall.arguments['spanHandle'], span.handle);
    expect(spanCall.arguments['kind'], 'Generic Error');
    expect(spanCall.arguments['message'], 'This was my fault');
    expect(spanCall.arguments['stackTrace'], isNotNull);
  });

  test('setErrorInfo on span calls to platform', () async {
    final span = DdSpan(ddTracesPlatform, systemTimeProvider, 12, ddLogger);
    span.log({
      'message': 'my message',
      'value': 0.24,
    });

    expect(
      log[0],
      isMethodCall('span.log', arguments: {
        'spanHandle': span.handle,
        'fields': {'message': 'my message', 'value': 0.24}
      }),
    );
  });
}
