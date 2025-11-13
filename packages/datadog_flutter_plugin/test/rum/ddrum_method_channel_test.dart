// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.
@TestOn('vm')
import 'dart:async';
import 'dart:math';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_flutter_plugin/src/rum/ddrum.dart';
import 'package:datadog_flutter_plugin/src/rum/ddrum_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockType {
  final int value;

  MockType(this.value);

  @override
  String toString() {
    return 'MockType($value)';
  }
}

class MockTimeProvider extends Mock implements DatadogTimeProvider {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DdRumMethodChannel ddRumPlatform;
  final List<MethodCall> log = [];

  final random = Random();
  DateTime randomTimestamp() {
    return DateTime.fromMillisecondsSinceEpoch(random.nextInt(1 << 32));
  }

  setUp(() {
    ddRumPlatform = DdRumMethodChannel();
    ambiguate(TestDefaultBinaryMessengerBinding.instance)
        ?.defaultBinaryMessenger
        .setMockMethodCallHandler(ddRumPlatform.methodChannel, (message) {
          log.add(message);
          if (message.method == 'getCurrentSessionId') {
            return Future.value('fake-session-id');
          }
          return null;
        });
  });

  tearDown(() {
    log.clear();
  });

  test('getCurrentSessionId calls to platform', () async {
    var sessionId = await ddRumPlatform.getCurrentSessionId();

    expect(sessionId, 'fake-session-id');
    expect(log, [isMethodCall('getCurrentSessionId', arguments: {})]);
  });

  test('cachedSessionId starts null', () async {
    var cachedSessionId = ddRumPlatform.cachedSessionId;

    // Then
    expect(cachedSessionId, isNull);
  });

  test('getCurrentSessionId sets cached sessionId', () async {
    var _ = await ddRumPlatform.getCurrentSessionId();
    var cachedSessionId = ddRumPlatform.cachedSessionId;

    // Then
    expect(cachedSessionId, 'fake-session-id');
  });

  test('onSessionChanged sets cachedSessionId', () async {
    // Given
    final sessionId = randomString();

    // When
    await ddRumPlatform.handleMethodCall(
      MethodCall('onSessionChanged', {
        'sessionId': sessionId,
        'discarded': randomBool(),
      }),
    );

    // Then
    expect(ddRumPlatform.cachedSessionId, sessionId);
  });

  test('startView calls to platform', () async {
    final timestamp = randomTimestamp();
    await ddRumPlatform.startView(timestamp, 'my_key', 'my_name', {
      'attribute': 'value',
    });

    expect(log, [
      isMethodCall(
        'startView',
        arguments: {
          'key': 'my_key',
          'name': 'my_name',
          'attributes': {
            'attribute': 'value',
            '_dd.timestamp': timestamp.millisecondsSinceEpoch,
          },
        },
      ),
    ]);
  });

  test('stopView calls to platform', () async {
    final timestamp = randomTimestamp();
    await ddRumPlatform.stopView(timestamp, 'my_key', {
      'stop_attribute': 'my_value',
    });

    expect(log, [
      isMethodCall(
        'stopView',
        arguments: {
          'key': 'my_key',
          'attributes': {
            'stop_attribute': 'my_value',
            '_dd.timestamp': timestamp.millisecondsSinceEpoch,
          },
        },
      ),
    ]);
  });

  test('addTiming calls to platform', () async {
    final timestamp = randomTimestamp();
    await ddRumPlatform.addTiming(timestamp, 'my timing name');

    expect(log, [
      isMethodCall('addTiming', arguments: {'name': 'my timing name'}),
    ]);
  });

  test('addViewLoadingTime calls to platform', () async {
    await ddRumPlatform.addViewLoadingTime(true);

    expect(log, [
      isMethodCall('addViewLoadingTime', arguments: {'overwrite': true}),
    ]);
  });

  test('startResource calls to platform', () async {
    final timestamp = randomTimestamp();
    await ddRumPlatform.startResource(
      timestamp,
      'resource_key',
      RumHttpMethod.get,
      'https://fakeresource.com/url',
      {'attribute_key': 'attribute_value'},
    );

    expect(log, [
      isMethodCall(
        'startResource',
        arguments: {
          'key': 'resource_key',
          'httpMethod': 'RumHttpMethod.get',
          'url': 'https://fakeresource.com/url',
          'attributes': {
            'attribute_key': 'attribute_value',
            '_dd.timestamp': timestamp.millisecondsSinceEpoch,
          },
        },
      ),
    ]);
  });

  test('stopResource calls to platform', () async {
    final timestamp = randomTimestamp();
    await ddRumPlatform.stopResource(
      timestamp,
      'resource_key',
      202,
      RumResourceType.image,
      41123,
      {'attribute_key': 'attribute_value'},
    );

    expect(log, [
      isMethodCall(
        'stopResource',
        arguments: {
          'key': 'resource_key',
          'statusCode': 202,
          'kind': 'RumResourceType.image',
          'size': 41123,
          'attributes': {
            'attribute_key': 'attribute_value',
            '_dd.timestamp': timestamp.millisecondsSinceEpoch,
          },
        },
      ),
    ]);
  });

  test('stopResourceWithError calls to platform with info', () async {
    final timestamp = randomTimestamp();
    final exception = TimeoutException(
      'Timeout retrieving resource',
      const Duration(seconds: 5),
    );
    await ddRumPlatform.stopResourceWithError(
      timestamp,
      'resource_key',
      exception,
      {'attribute_key': 'attribute_value'},
    );

    expect(log, [
      isMethodCall(
        'stopResourceWithError',
        arguments: {
          'key': 'resource_key',
          'message': exception.toString(),
          'type': exception.runtimeType.toString(),
          'attributes': {
            'attribute_key': 'attribute_value',
            '_dd.timestamp': timestamp.millisecondsSinceEpoch,
          },
        },
      ),
    ]);
  });

  test('stopResourceWithErrorInfo calls to platform', () async {
    final timestamp = randomTimestamp();
    await ddRumPlatform.stopResourceWithErrorInfo(
      timestamp,
      'resource_key',
      'Exception message',
      'Exception type',
      {'attribute_key': 'attribute_value'},
    );

    expect(log, [
      isMethodCall(
        'stopResourceWithError',
        arguments: {
          'key': 'resource_key',
          'message': 'Exception message',
          'type': 'Exception type',
          'attributes': {
            'attribute_key': 'attribute_value',
            '_dd.timestamp': timestamp.millisecondsSinceEpoch,
          },
        },
      ),
    ]);
  });

  test('addError calls to platform with info', () async {
    final timestamp = randomTimestamp();
    final exception = TimeoutException(
      'Timeout retrieving resource',
      const Duration(seconds: 5),
    );
    await ddRumPlatform.addError(
      timestamp,
      exception,
      RumErrorSource.source,
      null,
      'error_type',
      {'attribute_key': 'attribute_value'},
    );

    expect(log.length, 1);
    final call = log.first;
    expect(call.method, 'addError');
    expect(call.arguments['message'], exception.toString());
    expect(call.arguments['source'], 'RumErrorSource.source');
    expect(call.arguments['stackTrace'], isNull);
    expect(call.arguments['errorType'], 'error_type');
    expect(call.arguments['attributes'], {
      'attribute_key': 'attribute_value',
      '_dd.timestamp': timestamp.millisecondsSinceEpoch,
    });
  });

  test('addErrorInfo calls to platform with info', () async {
    final timestamp = randomTimestamp();
    await ddRumPlatform.addErrorInfo(
      timestamp,
      'Exception message',
      RumErrorSource.source,
      null,
      'error_type',
      {'attribute_key': 'attribute_value'},
    );

    expect(log.length, 1);
    final call = log.first;
    expect(call.method, 'addError');
    expect(call.arguments['message'], 'Exception message');
    expect(call.arguments['source'], 'RumErrorSource.source');
    expect(call.arguments['stackTrace'], isNull);
    expect(call.arguments['errorType'], 'error_type');
    expect(call.arguments['attributes'], {
      'attribute_key': 'attribute_value',
      '_dd.timestamp': timestamp.millisecondsSinceEpoch,
    });
  });

  test('addError passes stack trace string', () async {
    final timestamp = randomTimestamp();
    final stackTrace = StackTrace.current;
    final exception = TimeoutException(
      'Timeout retrieving resource',
      const Duration(seconds: 5),
    );
    await ddRumPlatform.addError(
      timestamp,
      exception,
      RumErrorSource.source,
      stackTrace,
      null,
      {'attribute_key': 'attribute_value'},
    );

    expect(log.length, 1);
    final call = log.first;
    expect(call.method, 'addError');
    expect(call.arguments['message'], exception.toString());
    expect(call.arguments['source'], 'RumErrorSource.source');
    expect(call.arguments['stackTrace'], stackTrace.toString());
    expect(call.arguments['errorType'], isNull);
    expect(call.arguments['attributes'], {
      'attribute_key': 'attribute_value',
      '_dd.timestamp': timestamp.millisecondsSinceEpoch,
    });
  });

  test('addErrorInfo passes stack trace string', () async {
    final timestamp = randomTimestamp();
    final stackTrace = StackTrace.current;
    await ddRumPlatform.addErrorInfo(
      timestamp,
      'Exception message',
      RumErrorSource.source,
      stackTrace,
      'error_type',
      {'attribute_key': 'attribute_value'},
    );

    expect(log.length, 1);
    final call = log.first;
    expect(call.method, 'addError');
    expect(call.arguments['message'], 'Exception message');
    expect(call.arguments['source'], 'RumErrorSource.source');
    expect(call.arguments['stackTrace'], stackTrace.toString());
    expect(call.arguments['errorType'], 'error_type');
    expect(call.arguments['attributes'], {
      'attribute_key': 'attribute_value',
      '_dd.timestamp': timestamp.millisecondsSinceEpoch,
    });
  });

  test('addAction calls to platform', () async {
    final timestamp = randomTimestamp();
    await ddRumPlatform.addAction(
      timestamp,
      RumActionType.tap,
      'fake_user_action',
      {'attribute_name': 'attribute_value'},
    );

    expect(log, [
      isMethodCall(
        'addAction',
        arguments: {
          'type': 'RumActionType.tap',
          'name': 'fake_user_action',
          'attributes': {
            'attribute_name': 'attribute_value',
            '_dd.timestamp': timestamp.millisecondsSinceEpoch,
          },
        },
      ),
    ]);
  });

  test('startAction calls to platform', () async {
    final timestamp = randomTimestamp();
    await ddRumPlatform.startAction(
      timestamp,
      RumActionType.scroll,
      'user_action_scroll',
      {'attribute_name': 'attribute_value'},
    );

    expect(log, [
      isMethodCall(
        'startAction',
        arguments: {
          'type': 'RumActionType.scroll',
          'name': 'user_action_scroll',
          'attributes': {
            'attribute_name': 'attribute_value',
            '_dd.timestamp': timestamp.millisecondsSinceEpoch,
          },
        },
      ),
    ]);
  });

  test('stopAction calls to platform', () async {
    final timestamp = randomTimestamp();
    await ddRumPlatform.stopAction(
      timestamp,
      RumActionType.swipe,
      'user_action_swipe',
      {'attribute_name': 'attribute_value'},
    );

    expect(log, [
      isMethodCall(
        'stopAction',
        arguments: {
          'type': 'RumActionType.swipe',
          'name': 'user_action_swipe',
          'attributes': {
            'attribute_name': 'attribute_value',
            '_dd.timestamp': timestamp.millisecondsSinceEpoch,
          },
        },
      ),
    ]);
  });

  test('addAttribute calls to platform', () async {
    await ddRumPlatform.addAttribute('attribute_key', 'my attribute value');

    expect(log, [
      isMethodCall(
        'addAttribute',
        arguments: {'key': 'attribute_key', 'value': 'my attribute value'},
      ),
    ]);
  });

  test('removeAttribute calls to platform', () async {
    await ddRumPlatform.removeAttribute('attribute_key');

    expect(log, [
      isMethodCall('removeAttribute', arguments: {'key': 'attribute_key'}),
    ]);
  });

  test('addFeatureFlagEvaluation calls to platform', () async {
    await ddRumPlatform.addFeatureFlagEvaluation('key_name', 'key_value');

    expect(log, [
      isMethodCall(
        'addFeatureFlagEvaluation',
        arguments: {'name': 'key_name', 'value': 'key_value'},
      ),
    ]);
  });

  test('stopSession calls to platform', () async {
    await ddRumPlatform.stopSession();

    expect(log, [isMethodCall('stopSession', arguments: <String, Object?>{})]);
  });

  test('reportLongTask calls to platform', () async {
    final now = DateTime.now();
    final duration = Random().nextInt(1000) + 100;

    await ddRumPlatform.reportLongTask(now, duration);

    expect(log, [
      isMethodCall(
        'reportLongTask',
        arguments: {'at': now.millisecondsSinceEpoch, 'duration': duration},
      ),
    ]);
  });

  test('updatePerformanceMetrics calls to platform', () async {
    await ddRumPlatform.updatePerformanceMetrics([0.2, 0.3], [0.11, 0.25]);

    expect(log, [
      isMethodCall(
        'updatePerformanceMetrics',
        arguments: {
          'buildTimes': [0.2, 0.3],
          'rasterTimes': [0.11, 0.25],
        },
      ),
    ]);
  });
}
