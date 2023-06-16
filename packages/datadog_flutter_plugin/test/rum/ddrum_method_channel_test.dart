// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:async';
import 'dart:math';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_flutter_plugin/src/rum/ddrum_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class MockType {
  final int value;

  MockType(this.value);

  @override
  String toString() {
    return 'MockType($value)';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DdRumMethodChannel ddRumPlatform;
  final List<MethodCall> log = [];

  setUp(() {
    ddRumPlatform = DdRumMethodChannel();
    ambiguate(TestDefaultBinaryMessengerBinding.instance)
        ?.defaultBinaryMessenger
        .setMockMethodCallHandler(ddRumPlatform.methodChannel, (message) {
      log.add(message);
      return null;
    });
  });

  tearDown(() {
    log.clear();
  });

  test('startView calls to platform', () async {
    await ddRumPlatform.startView('my_key', 'my_name', {'attribute': 'value'});

    expect(log, [
      isMethodCall('startView', arguments: {
        'key': 'my_key',
        'name': 'my_name',
        'attributes': {'attribute': 'value'}
      })
    ]);
  });

  test('stopView calls to platform', () async {
    await ddRumPlatform.stopView('my_key', {'stop_attribute': 'my_value'});

    expect(log, [
      isMethodCall('stopView', arguments: {
        'key': 'my_key',
        'attributes': {'stop_attribute': 'my_value'}
      })
    ]);
  });

  test('addTiming calls to platform', () async {
    await ddRumPlatform.addTiming('my timing name');

    expect(log, [
      isMethodCall('addTiming', arguments: {'name': 'my timing name'})
    ]);
  });

  test('startResourceLoading calls to platform', () async {
    await ddRumPlatform.startResourceLoading('resource_key', RumHttpMethod.get,
        'https://fakeresource.com/url', {'attribute_key': 'attribute_value'});

    expect(log, [
      isMethodCall('startResourceLoading', arguments: {
        'key': 'resource_key',
        'httpMethod': 'RumHttpMethod.get',
        'url': 'https://fakeresource.com/url',
        'attributes': {'attribute_key': 'attribute_value'}
      })
    ]);
  });

  test('stopResourceLoading calls to platform', () async {
    await ddRumPlatform.stopResourceLoading('resource_key', 202,
        RumResourceType.image, 41123, {'attribute_key': 'attribute_value'});

    expect(log, [
      isMethodCall('stopResourceLoading', arguments: {
        'key': 'resource_key',
        'statusCode': 202,
        'kind': 'RumResourceType.image',
        'size': 41123,
        'attributes': {'attribute_key': 'attribute_value'}
      })
    ]);
  });

  test('stopResourceLoadingWithError calls to platform with info', () async {
    final exception = TimeoutException(
        'Timeout retrieving resource', const Duration(seconds: 5));
    await ddRumPlatform.stopResourceLoadingWithError(
        'resource_key', exception, {'attribute_key': 'attribute_value'});

    expect(log, [
      isMethodCall('stopResourceLoadingWithError', arguments: {
        'key': 'resource_key',
        'message': exception.toString(),
        'type': exception.runtimeType.toString(),
        'attributes': {'attribute_key': 'attribute_value'}
      })
    ]);
  });

  test('stopResourceLoadingWithErrorInfo calls to platform', () async {
    await ddRumPlatform.stopResourceLoadingWithErrorInfo(
        'resource_key',
        'Exception message',
        'Exception type',
        {'attribute_key': 'attribute_value'});

    expect(log, [
      isMethodCall('stopResourceLoadingWithError', arguments: {
        'key': 'resource_key',
        'message': 'Exception message',
        'type': 'Exception type',
        'attributes': {'attribute_key': 'attribute_value'}
      })
    ]);
  });

  test('addError calls to platform with info', () async {
    final exception = TimeoutException(
        'Timeout retrieving resource', const Duration(seconds: 5));
    await ddRumPlatform.addError(exception, RumErrorSource.source, null,
        'error_type', {'attribute_key': 'attribute_value'});

    expect(log.length, 1);
    final call = log.first;
    expect(call.method, 'addError');
    expect(call.arguments['message'], exception.toString());
    expect(call.arguments['source'], 'RumErrorSource.source');
    expect(call.arguments['stackTrace'], isNull);
    expect(call.arguments['errorType'], 'error_type');
    expect(call.arguments['attributes'], {
      // '_dd.error.source_type': 'flutter'
      'attribute_key': 'attribute_value'
    });
  });

  test('addErrorInfo calls to platform with info', () async {
    await ddRumPlatform.addErrorInfo('Exception message', RumErrorSource.source,
        null, 'error_type', {'attribute_key': 'attribute_value'});

    expect(log.length, 1);
    final call = log.first;
    expect(call.method, 'addError');
    expect(call.arguments['message'], 'Exception message');
    expect(call.arguments['source'], 'RumErrorSource.source');
    expect(call.arguments['stackTrace'], isNull);
    expect(call.arguments['errorType'], 'error_type');
    expect(call.arguments['attributes'], {
      // '_dd.error.source_type': 'flutter'
      'attribute_key': 'attribute_value'
    });
  });

  test('addError passes stack trace string', () async {
    final stackTrace = StackTrace.current;
    final exception = TimeoutException(
        'Timeout retrieving resource', const Duration(seconds: 5));
    await ddRumPlatform.addError(exception, RumErrorSource.source, stackTrace,
        null, {'attribute_key': 'attribute_value'});

    expect(log.length, 1);
    final call = log.first;
    expect(call.method, 'addError');
    expect(call.arguments['message'], exception.toString());
    expect(call.arguments['source'], 'RumErrorSource.source');
    expect(call.arguments['stackTrace'], stackTrace.toString());
    expect(call.arguments['errorType'], isNull);
    expect(call.arguments['attributes'], {
      // '_dd.error.source_type': 'flutter'
      'attribute_key': 'attribute_value'
    });
  });

  test('addErrorInfo passes stack trace string', () async {
    final stackTrace = StackTrace.current;
    await ddRumPlatform.addErrorInfo('Exception message', RumErrorSource.source,
        stackTrace, 'error_type', {'attribute_key': 'attribute_value'});

    expect(log.length, 1);
    final call = log.first;
    expect(call.method, 'addError');
    expect(call.arguments['message'], 'Exception message');
    expect(call.arguments['source'], 'RumErrorSource.source');
    expect(call.arguments['stackTrace'], stackTrace.toString());
    expect(call.arguments['errorType'], 'error_type');
    expect(call.arguments['attributes'], {
      // '_dd.error.source_type': 'flutter'
      'attribute_key': 'attribute_value'
    });
  });

  test('addUserAction calls to platform', () async {
    await ddRumPlatform
        .addUserAction(RumUserActionType.tap, 'fake_user_action', {
      'attribute_name': 'attribute_value',
    });

    expect(log, [
      isMethodCall('addUserAction', arguments: {
        'type': 'RumUserActionType.tap',
        'name': 'fake_user_action',
        'attributes': {'attribute_name': 'attribute_value'}
      })
    ]);
  });

  test('startUserAction calls to platform', () async {
    await ddRumPlatform.startUserAction(RumUserActionType.scroll,
        'user_action_scroll', {'attribute_name': 'attribute_value'});

    expect(log, [
      isMethodCall('startUserAction', arguments: {
        'type': 'RumUserActionType.scroll',
        'name': 'user_action_scroll',
        'attributes': {'attribute_name': 'attribute_value'}
      })
    ]);
  });

  test('stopUserAction calls to platform', () async {
    await ddRumPlatform.stopUserAction(RumUserActionType.swipe,
        'user_action_swipe', {'attribute_name': 'attribute_value'});

    expect(log, [
      isMethodCall('stopUserAction', arguments: {
        'type': 'RumUserActionType.swipe',
        'name': 'user_action_swipe',
        'attributes': {'attribute_name': 'attribute_value'}
      })
    ]);
  });

  test('addAttribute calls to platform', () async {
    await ddRumPlatform.addAttribute('attribute_key', 'my attribute value');

    expect(log, [
      isMethodCall('addAttribute',
          arguments: {'key': 'attribute_key', 'value': 'my attribute value'})
    ]);
  });

  test('removeAttribute calls to platform', () async {
    await ddRumPlatform.removeAttribute('attribute_key');

    expect(log, [
      isMethodCall('removeAttribute', arguments: {'key': 'attribute_key'})
    ]);
  });

  test('addFeatureFlagEvaluation calls to platform', () async {
    await ddRumPlatform.addFeatureFlagEvaluation('key_name', 'key_value');

    expect(log, [
      isMethodCall('addFeatureFlagEvaluation', arguments: {
        'name': 'key_name',
        'value': 'key_value',
      })
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
      isMethodCall('reportLongTask', arguments: {
        'at': now.millisecondsSinceEpoch,
        'duration': duration,
      }),
    ]);
  });

  test('updatePerformanceMetrics calls to platform', () async {
    await ddRumPlatform.updatePerformanceMetrics([0.2, 0.3], [0.11, 0.25]);

    expect(log, [
      isMethodCall('updatePerformanceMetrics', arguments: {
        'buildTimes': [0.2, 0.3],
        'rasterTimes': [0.11, 0.25],
      }),
    ]);
  });

  test('sessionId returns empty string for no session', () {
    expect(ddRumPlatform.sessionId, isEmpty);
  });

  test('rumSessionStarted from method channel sets sessionId', () async {
    await ddRumPlatform.initialize(
        RumConfiguration(applicationId: 'fake-application-id'),
        InternalLogger());
    await ambiguate(TestDefaultBinaryMessengerBinding.instance)
        ?.defaultBinaryMessenger
        .handlePlatformMessage(
          'datadog_sdk_flutter.rum',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall(
              'rumSessionStarted',
              {'sessionId': 'fake-session-id', 'sampled': false},
            ),
          ),
          null,
        );

    expect(ddRumPlatform.sessionId, 'fake-session-id');
  });

  test(
      'rumSessionStarted from method channel sets sessionId to empty if sampled',
      () async {
    await ddRumPlatform.initialize(
        RumConfiguration(applicationId: 'fake-application-id'),
        InternalLogger());
    await ambiguate(TestDefaultBinaryMessengerBinding.instance)
        ?.defaultBinaryMessenger
        .handlePlatformMessage(
          'datadog_sdk_flutter.rum',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall(
              'rumSessionStarted',
              {'sessionId': 'fake-session-id', 'sampled': true},
            ),
          ),
          null,
        );

    expect(ddRumPlatform.sessionId, '');
  });

  test('rumSessionStarted from method channel calls callback', () async {
    await ddRumPlatform.initialize(
        RumConfiguration(applicationId: 'fake-application-id'),
        InternalLogger());
    String? callbackSessionId;
    ddRumPlatform.sessionStarted = (sessionId) {
      callbackSessionId = sessionId;
    };

    await ambiguate(TestDefaultBinaryMessengerBinding.instance)
        ?.defaultBinaryMessenger
        .handlePlatformMessage(
          'datadog_sdk_flutter.rum',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall(
              'rumSessionStarted',
              {'sessionId': 'fake-session-id', 'sampled': false},
            ),
          ),
          null,
        );

    expect(callbackSessionId, 'fake-session-id');
  });
}
