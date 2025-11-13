// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
@TestOn('browser')
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart'
    hide DurationHelpers;
import 'package:datadog_flutter_plugin/src/rum/rum.dart';
import 'package:datadog_flutter_plugin/src/rum/web/raw_events.dart';
import 'package:datadog_flutter_plugin/src/rum/web/resource_tracker.dart';
import 'package:datadog_flutter_plugin/src/rum/web/rum_web_plugin.dart';
import 'package:datadog_flutter_plugin/src/web_helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'event_matchers.dart';

class MockWebPlugin extends Mock implements RumWebPluginImpl {}

final navigationStart = DateTime.now();

void main() {
  late MockWebPlugin mockPlugin;

  JSNumber getRelativeEventTime(DateTime dateTime) {
    return (dateTime.difference(navigationStart).inMilliseconds).toJS;
  }

  setUp(() {
    mockPlugin = MockWebPlugin();
    // This serves as a fallback for `JSValue` in wasm tests. `
    registerFallbackValue(1.toJS);

    when(() => mockPlugin.getEventRelativeTime(any())).thenAnswer((call) {
      final timestamp = call.positionalArguments[0] as DateTime;
      return getRelativeEventTime(timestamp);
    });
  });

  test('startResource sends no events', () {
    // Given
    final tracker = ResourceTracker(mockPlugin);

    // When
    tracker.startResource(
      DateTime.now(),
      'fake_key',
      RumHttpMethod.get,
      'fake_url',
      {},
    );

    // Then
    verifyZeroInteractions(mockPlugin);
  });

  test('stopResource sends resource event', () {
    // Given
    final tracker = ResourceTracker(mockPlugin);
    final startTime = DateTime.now();
    final endTime = startTime.add(Duration(seconds: 20));
    final keyName = randomString();
    final url = randomString();
    final size = randomInt();

    // When
    tracker.startResource(startTime, keyName, RumHttpMethod.get, url, {});
    tracker.stopResource(
      endTime,
      keyName,
      200,
      RumResourceType.image,
      size,
      {},
    );

    // Then
    final expectedEventTime = getRelativeEventTime(endTime);
    final captured = verify(
      () => mockPlugin.addEvent(expectedEventTime, captureAny(), captureAny()),
    ).captured;
    // Despite having a matcher, make sure all properties got transferred to this event manually
    // to ensure the JS Interop is coded properly.
    final actualEvent = captured[0] as RumWebRawResourceEvent;
    expect(actualEvent.date, endTime.millisecondsSinceEpoch.toJS);
    expect(actualEvent.resource.id, isNotNull);
    expect(actualEvent.type, 'resource');
    expect(actualEvent.resource.type, 'image');
    expect(actualEvent.resource.url, url);
    expect(
      actualEvent.resource.duration,
      endTime.difference(startTime).inNanoseconds.toJS,
    );
    expect(actualEvent.resource.method, 'GET');
    expect(actualEvent.resource.statusCode, 200.toJS);
    expect(actualEvent.resource.transferSize, size.toJS);
  });

  test('stopResource sends resource event merges attributes to context', () {
    // Given
    final tracker = ResourceTracker(mockPlugin);
    final startTime = DateTime.now();
    final endTime = startTime.add(Duration(seconds: 20));
    final keyName = randomString();
    final url = randomString();
    final size = randomInt();

    // When
    tracker.startResource(startTime, keyName, RumHttpMethod.get, url, {
      'attribute_1': 'value',
      'attribute_2': 'value_2',
    });
    tracker.stopResource(endTime, keyName, 200, RumResourceType.image, size, {
      'attribute_2': 'finished_value',
      'attribute_3': 'extra_value',
    });

    // Then
    final expectedEventTime = getRelativeEventTime(endTime);
    final expectedEvent = RumWebRawResourceEvent(
      date: endTime.millisecondsSinceEpoch.toJS,
      resource: RumWebRawResourceData(
        id: 'any',
        type: 'image',
        url: url,
        duration: (endTime.difference(startTime).inNanoseconds).toJS,
        method: 'GET',
        status_code: 200.toJS,
        transfer_size: size.toJS,
      ),
      dd: RumWebRawResourceDdData(discarded: false),
      context: {
        'attribute_1': 'value',
        'attribute_2': 'finished_value',
        'attribute_3': 'extra_value',
      },
    );
    final captured = verify(
      () => mockPlugin.addEvent(expectedEventTime, captureAny(), captureAny()),
    ).captured;
    expect(captured[0], equalsResourceEvent(expectedEvent));
  });

  test('stopResourceWithError sends error event', () {
    // Given
    final tracker = ResourceTracker(mockPlugin);
    final startTime = DateTime.now();
    final endTime = startTime.add(Duration(seconds: 20));
    final keyName = randomString();
    final url = randomString();

    // When
    tracker.startResource(startTime, keyName, RumHttpMethod.get, url, {});
    final error = FormatException('message');
    tracker.stopResourceWithError(endTime, keyName, error, {});

    // Then
    final expectedEventTime = getRelativeEventTime(endTime);
    final captured = verify(
      () => mockPlugin.addEvent(expectedEventTime, captureAny(), captureAny()),
    ).captured;
    final errorEvent = captured[0] as RumWebRawErrorEvent;
    expect(errorEvent.date, endTime.millisecondsSinceEpoch.toJS);
    expect(errorEvent.error.id, isNotNull);
    expect(errorEvent.error.message, error.toString());
    expect(errorEvent.error.source, 'network');
    expect(errorEvent.error.type, 'FormatException');
    expect(errorEvent.error.resource?.method, 'GET');
    expect(errorEvent.error.resource?.statusCode, 0);
    expect(errorEvent.error.resource?.url, url);
  });

  test(
    'stopResourceWithError sends resource event with error merges attributes to context',
    () {
      // Given
      final tracker = ResourceTracker(mockPlugin);
      final startTime = DateTime.now();
      final endTime = startTime.add(Duration(seconds: 20));
      final keyName = randomString();
      final url = randomString();

      // When
      tracker.startResource(startTime, keyName, RumHttpMethod.get, url, {
        'attribute_1': 'value',
        'attribute_2': 'value_2',
      });
      final error = FormatException('message');
      tracker.stopResourceWithError(endTime, keyName, error, {
        'attribute_2': 'finished_value',
        'attribute_3': 'extra_value',
      });

      // Then
      final expectedEventTime = getRelativeEventTime(endTime);
      final expectedContext = attributesToJs({
        'attribute_1': 'value',
        'attribute_2': 'finished_value',
        'attribute_3': 'extra_value',
      }, 'attributes');
      final captured = verify(
        () =>
            mockPlugin.addEvent(expectedEventTime, captureAny(), captureAny()),
      ).captured;
      final errorEvent = captured[0] as RumWebRawErrorEvent;
      expect(errorEvent.context, equalsContext(expectedContext));
    },
  );

  test('stopResourceWithErrorInfo sends resource event with info', () {
    // Given
    final tracker = ResourceTracker(mockPlugin);
    final startTime = DateTime.now();
    final endTime = startTime.add(Duration(seconds: 20));
    final keyName = randomString();
    final url = randomString();
    final errorType = randomString();
    final errorMessage = randomString();

    // When
    tracker.startResource(startTime, keyName, RumHttpMethod.get, url, {});
    tracker.stopResourceWithErrorInfo(
      endTime,
      keyName,
      errorMessage,
      errorType,
      {},
    );

    // Then
    final expectedEventTime = getRelativeEventTime(endTime);
    final captured = verify(
      () => mockPlugin.addEvent(expectedEventTime, captureAny(), captureAny()),
    ).captured;
    final errorEvent = captured[0] as RumWebRawErrorEvent;
    expect(errorEvent.date, endTime.millisecondsSinceEpoch.toJS);
    expect(errorEvent.error.id, isNotNull);
    expect(errorEvent.error.message, errorMessage);
    expect(errorEvent.error.source, 'network');
    expect(errorEvent.error.type, errorType);
    expect(errorEvent.error.resource?.method, 'GET');
    expect(errorEvent.error.resource?.statusCode, 0);
    expect(errorEvent.error.resource?.url, url);
  });

  test(
    'stopResourceWithError sends resource event with error merges attributes to context',
    () {
      // Given
      final tracker = ResourceTracker(mockPlugin);
      final startTime = DateTime.now();
      final endTime = startTime.add(Duration(seconds: 20));
      final keyName = randomString();
      final url = randomString();
      final errorType = randomString();
      final errorMessage = randomString();

      // When
      tracker.startResource(startTime, keyName, RumHttpMethod.get, url, {
        'attribute_1': 'value',
        'attribute_2': 'value_2',
      });
      tracker.stopResourceWithErrorInfo(
        endTime,
        keyName,
        errorMessage,
        errorType,
        {'attribute_2': 'finished_value', 'attribute_3': 'extra_value'},
      );

      // Then
      final expectedEventTime = getRelativeEventTime(endTime);
      final expectedContext = attributesToJs({
        'attribute_1': 'value',
        'attribute_2': 'finished_value',
        'attribute_3': 'extra_value',
      }, 'attributes');
      final captured = verify(
        () =>
            mockPlugin.addEvent(expectedEventTime, captureAny(), captureAny()),
      ).captured;
      final errorEvent = captured[0] as RumWebRawErrorEvent;
      expect(errorEvent.context, equalsContext(expectedContext));
    },
  );

  test('stopResource transfers traceId and spanId to DdData', () {
    // Given
    final tracker = ResourceTracker(mockPlugin);
    final startTime = DateTime.now();
    final endTime = startTime.add(Duration(seconds: 20));
    final keyName = randomString();
    final url = randomString();
    final size = randomInt();
    // These are not real trace Ids, but proves the values get transferred
    final traceId = randomString();
    final spanId = randomString();
    final rulePsr = randomDouble(min: 0.0, max: 1.0);

    // When
    tracker.startResource(startTime, keyName, RumHttpMethod.get, url, {
      DatadogRumPlatformAttributeKey.traceID: traceId,
      DatadogRumPlatformAttributeKey.spanID: spanId,
      DatadogRumPlatformAttributeKey.rulePsr: rulePsr,
    });
    tracker.stopResource(
      endTime,
      keyName,
      200,
      RumResourceType.image,
      size,
      {},
    );

    // Then
    final expectedEventTime = getRelativeEventTime(endTime);
    final captured = verify(
      () => mockPlugin.addEvent(expectedEventTime, captureAny(), captureAny()),
    ).captured;
    final actualEvent = captured[0] as RumWebRawResourceEvent;
    expect(
      actualEvent.context.getProperty(
        DatadogRumPlatformAttributeKey.traceID.toJS,
      ),
      isNull,
    );
    expect(
      actualEvent.context.getProperty(
        DatadogRumPlatformAttributeKey.spanID.toJS,
      ),
      isNull,
    );
    expect(
      actualEvent.context.getProperty(
        DatadogRumPlatformAttributeKey.rulePsr.toJS,
      ),
      isNull,
    );
    expect(actualEvent.dd.traceId, traceId);
    expect(actualEvent.dd.spanId, spanId);
    expect(actualEvent.dd.rulePsr, rulePsr.toJS);
  });
}
