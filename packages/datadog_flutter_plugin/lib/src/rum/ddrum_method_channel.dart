// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../datadog_flutter_plugin.dart';
import '../../datadog_internal.dart';
import 'ddrum_platform_interface.dart';
import 'rum_mapper_proxy_stub.dart'
    if (dart.library.io) 'rum_mapper_proxy.dart';

class DdRumMethodChannel extends DdRumPlatform {
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(
    'datadog_sdk_flutter.rum',
  );

  // ignore: unused_field
  RumMapperProxy? _mapperProxy;

  String? _cachedSessionId;
  @override
  String? get cachedSessionId => _cachedSessionId;

  @override
  Future<void> enable(
    DatadogSdk core,
    DatadogRumConfiguration configuration,
  ) async {
    _mapperProxy = RumMapperProxy.fromConfiguration(
      configuration,
      core.internalLogger,
    );

    if (ServicesBinding.rootIsolateToken != null) {
      methodChannel.setMethodCallHandler(handleMethodCall);
    }

    await methodChannel.invokeMethod('enable', {
      'configuration': configuration.encode(),
    });
  }

  @override
  Future<void> deinitialize() {
    return methodChannel.invokeMethod('deinitialize', {});
  }

  @override
  Future<String?> getCurrentSessionId() async {
    final sessionId = await methodChannel.invokeMethod<String>(
      'getCurrentSessionId',
      {},
    );
    // Pulling this directly means this is the most up to date it can be.
    _cachedSessionId = sessionId;
    return sessionId;
  }

  @override
  Future<void> addTiming(DateTime timestamp, String name) {
    return methodChannel.invokeMethod('addTiming', {'name': name});
  }

  @override
  Future<void> startView(
    DateTime timestamp,
    String key,
    String name,
    Map<String, Object?> attributes,
  ) {
    final timestampMs = timestamp.millisecondsSinceEpoch;
    return methodChannel.invokeMethod('startView', {
      'key': key,
      'name': name,
      'attributes': {
        ...attributes,
        DatadogPlatformAttributeKey.timestamp: timestampMs,
      },
    });
  }

  @override
  Future<void> stopView(
    DateTime timestamp,
    String key,
    Map<String, Object?> attributes,
  ) {
    final timestampMs = timestamp.millisecondsSinceEpoch;
    return methodChannel.invokeMethod('stopView', {
      'key': key,
      'attributes': {
        ...attributes,
        DatadogPlatformAttributeKey.timestamp: timestampMs,
      },
    });
  }

  @override
  Future<void> startResource(
    DateTime timestamp,
    String key,
    RumHttpMethod httpMethod,
    String url, [
    Map<String, Object?> attributes = const {},
  ]) {
    final timestampMs = timestamp.millisecondsSinceEpoch;
    return methodChannel.invokeMethod('startResource', {
      'key': key,
      'httpMethod': httpMethod.toString(),
      'url': url,
      'attributes': {
        ...attributes,
        DatadogPlatformAttributeKey.timestamp: timestampMs,
      },
    });
  }

  @override
  Future<void> stopResource(
    DateTime timestamp,
    String key,
    int? statusCode,
    RumResourceType kind, [
    int? size,
    Map<String, Object?> attributes = const {},
  ]) {
    final timestampMs = timestamp.millisecondsSinceEpoch;
    return methodChannel.invokeMethod('stopResource', {
      'key': key,
      'statusCode': statusCode,
      'kind': kind.toString(),
      'size': size,
      'attributes': {
        ...attributes,
        DatadogPlatformAttributeKey.timestamp: timestampMs,
      },
    });
  }

  @override
  Future<void> stopResourceWithError(
    DateTime timestamp,
    String key,
    Exception error, [
    Map<String, Object?> attributes = const {},
  ]) {
    return stopResourceWithErrorInfo(
      timestamp,
      key,
      error.toString(),
      error.runtimeType.toString(),
      attributes,
    );
  }

  @override
  Future<void> stopResourceWithErrorInfo(
    DateTime timestamp,
    String key,
    String message,
    String type, [
    Map<String, Object?> attributes = const {},
  ]) {
    final timestampMs = timestamp.millisecondsSinceEpoch;
    return methodChannel.invokeMethod('stopResourceWithError', {
      'key': key,
      'message': message,
      'type': type,
      'attributes': {
        ...attributes,
        DatadogPlatformAttributeKey.timestamp: timestampMs,
      },
    });
  }

  @override
  Future<void> addError(
    DateTime timestamp,
    Object error,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes,
  ) {
    return addErrorInfo(
      timestamp,
      error.toString(),
      source,
      stackTrace,
      errorType,
      attributes,
    );
  }

  @override
  Future<void> addViewLoadingTime(bool overwrite) {
    return methodChannel.invokeMethod('addViewLoadingTime', {
      'overwrite': overwrite,
    });
  }

  @override
  Future<void> addErrorInfo(
    DateTime timestamp,
    String message,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes,
  ) {
    final timestampMs = timestamp.millisecondsSinceEpoch;
    return methodChannel.invokeMethod('addError', {
      'message': message,
      'source': source.toString(),
      'stackTrace': stackTrace?.toString(),
      'errorType': errorType,
      'attributes': {
        ...attributes,
        DatadogPlatformAttributeKey.timestamp: timestampMs,
      },
    });
  }

  @override
  Future<void> addAction(
    DateTime timestamp,
    RumActionType type,
    String? name,
    Map<String, Object?> attributes,
  ) {
    final timestampMs = timestamp.millisecondsSinceEpoch;
    return methodChannel.invokeMethod('addAction', {
      'type': type.toString(),
      'name': name,
      'attributes': {
        ...attributes,
        DatadogPlatformAttributeKey.timestamp: timestampMs,
      },
    });
  }

  @override
  Future<void> startAction(
    DateTime timestamp,
    RumActionType type,
    String name,
    Map<String, Object?> attributes,
  ) {
    final timestampMs = timestamp.millisecondsSinceEpoch;
    return methodChannel.invokeMethod('startAction', {
      'type': type.toString(),
      'name': name,
      'attributes': {
        ...attributes,
        DatadogPlatformAttributeKey.timestamp: timestampMs,
      },
    });
  }

  @override
  Future<void> stopAction(
    DateTime timestamp,
    RumActionType type,
    String name,
    Map<String, Object?> attributes,
  ) {
    final timestampMs = timestamp.millisecondsSinceEpoch;
    return methodChannel.invokeMethod('stopAction', {
      'type': type.toString(),
      'name': name,
      'attributes': {
        ...attributes,
        DatadogPlatformAttributeKey.timestamp: timestampMs,
      },
    });
  }

  @override
  Future<void> addAttribute(String key, Object? value) {
    return methodChannel.invokeMethod('addAttribute', {
      'key': key,
      'value': value,
    });
  }

  @override
  Future<void> setInternalViewAttribute(String key, Object value) {
    return methodChannel.invokeMethod('setInternalViewAttribute', {
      'key': key,
      'value': value,
    });
  }

  @override
  Future<void> removeAttribute(String key) {
    return methodChannel.invokeMethod('removeAttribute', {'key': key});
  }

  @override
  Future<void> addFeatureFlagEvaluation(String name, Object value) {
    return methodChannel.invokeMethod('addFeatureFlagEvaluation', {
      'name': name,
      'value': value,
    });
  }

  @override
  Future<void> stopSession() {
    _cachedSessionId = null;
    return methodChannel.invokeMethod('stopSession', <String, Object?>{});
  }

  @override
  Future<void> reportLongTask(DateTime at, int durationMs) {
    return methodChannel.invokeMethod('reportLongTask', {
      'at': at.millisecondsSinceEpoch,
      'duration': durationMs,
    });
  }

  @override
  Future<void> updatePerformanceMetrics(
    List<double> buildTimes,
    List<double> rasterTimes,
  ) {
    return methodChannel.invokeMethod('updatePerformanceMetrics', {
      'buildTimes': buildTimes,
      'rasterTimes': rasterTimes,
    });
  }

  void _onSessionChanged(MethodCall call) {
    if (call.arguments case final Map<dynamic, dynamic> arguments?) {
      final sessionId = arguments['sessionId'];
      if (sessionId is String) {
        _cachedSessionId = sessionId;
      }
    }
  }

  @visibleForTesting
  Future<dynamic> handleMethodCall(MethodCall call) async {
    if (call.method.startsWith('map')) {
      if (_mapperProxy case final RumMethodChannelMapperProxy mapper) {
        return mapper.handleMethodCall(call);
      }
    }
    switch (call.method) {
      case 'onSessionChanged':
        return _onSessionChanged(call);
    }
    throw MissingPluginException(
      'Could not find a method to call for ${call.method}',
    );
  }
}
