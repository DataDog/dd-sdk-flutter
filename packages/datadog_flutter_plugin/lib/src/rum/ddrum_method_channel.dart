// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../datadog_flutter_plugin.dart';
import '../internal_logger.dart';
import 'ddrum_platform_interface.dart';

class DdRumMethodChannel extends DdRumPlatform {
  @visibleForTesting
  final MethodChannel methodChannel =
      const MethodChannel('datadog_sdk_flutter.rum');

  @override
  Future<void> enable(
      DatadogSdk core, DatadogRumConfiguration configuration) async {
    final callbackHandler = MethodCallHandler(
      viewEventMapper: configuration.viewEventMapper,
      actionEventMapper: configuration.actionEventMapper,
      resourceEventMapper: configuration.resourceEventMapper,
      errorEventMapper: configuration.errorEventMapper,
      longTaskEventMapper: configuration.longTaskEventMapper,
      internalLogger: core.internalLogger,
    );

    if (ServicesBinding.rootIsolateToken != null) {
      methodChannel.setMethodCallHandler(callbackHandler.handleMethodCall);
    }

    return methodChannel.invokeMethod('enable', {
      'configuration': configuration.encode(),
    });
  }

  @override
  Future<void> deinitialize() {
    return methodChannel.invokeMethod('deinitialize', {});
  }

  @override
  Future<String?> getCurrentSessionId() async {
    return methodChannel.invokeMethod<String>('getCurrentSessionId', {});
  }

  @override
  Future<void> addTiming(String name) {
    return methodChannel.invokeMethod(
      'addTiming',
      {'name': name},
    );
  }

  @override
  Future<void> startView(
      String key, String name, Map<String, Object?> attributes) {
    return methodChannel.invokeMethod(
      'startView',
      {'key': key, 'name': name, 'attributes': attributes},
    );
  }

  @override
  Future<void> stopView(String key, Map<String, Object?> attributes) {
    return methodChannel.invokeMethod(
      'stopView',
      {'key': key, 'attributes': attributes},
    );
  }

  @override
  Future<void> startResource(
    String key,
    RumHttpMethod httpMethod,
    String url, [
    Map<String, Object?> attributes = const {},
  ]) {
    return methodChannel.invokeMethod('startResource', {
      'key': key,
      'httpMethod': httpMethod.toString(),
      'url': url,
      'attributes': attributes
    });
  }

  @override
  Future<void> stopResource(String key, int? statusCode, RumResourceType kind,
      [int? size, Map<String, Object?>? attributes = const {}]) {
    return methodChannel.invokeMethod('stopResource', {
      'key': key,
      'statusCode': statusCode,
      'kind': kind.toString(),
      'size': size,
      'attributes': attributes
    });
  }

  @override
  Future<void> stopResourceWithError(String key, Exception error,
      [Map<String, Object?> attributes = const {}]) {
    return stopResourceWithErrorInfo(
        key, error.toString(), error.runtimeType.toString(), attributes);
  }

  @override
  Future<void> stopResourceWithErrorInfo(
    String key,
    String message,
    String type, [
    Map<String, Object?> attributes = const {},
  ]) {
    return methodChannel.invokeMethod('stopResourceWithError', {
      'key': key,
      'message': message,
      'type': type,
      'attributes': attributes,
    });
  }

  @override
  Future<void> addError(
    Object error,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes,
  ) {
    return addErrorInfo(
        error.toString(), source, stackTrace, errorType, attributes);
  }

  @override
  Future<void> addViewLoadingTime(bool overwrite) {
    return methodChannel.invokeMethod('addViewLoadingTime', {
      'overwrite': overwrite,
    });
  }

  @override
  Future<void> addErrorInfo(
      String message,
      RumErrorSource source,
      StackTrace? stackTrace,
      String? errorType,
      Map<String, Object?> attributes) {
    return methodChannel.invokeMethod('addError', {
      'message': message,
      'source': source.toString(),
      'stackTrace': stackTrace?.toString(),
      'errorType': errorType,
      'attributes': attributes
    });
  }

  @override
  Future<void> addAction(
      RumActionType type, String? name, Map<String, Object?> attributes) {
    return methodChannel.invokeMethod('addAction', {
      'type': type.toString(),
      'name': name,
      'attributes': attributes,
    });
  }

  @override
  Future<void> startAction(
      RumActionType type, String name, Map<String, Object?> attributes) {
    return methodChannel.invokeMethod('startAction',
        {'type': type.toString(), 'name': name, 'attributes': attributes});
  }

  @override
  Future<void> stopAction(
      RumActionType type, String name, Map<String, Object?> attributes) {
    return methodChannel.invokeMethod('stopAction',
        {'type': type.toString(), 'name': name, 'attributes': attributes});
  }

  @override
  Future<void> addAttribute(String key, Object? value) {
    return methodChannel
        .invokeMethod('addAttribute', {'key': key, 'value': value});
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
      List<double> buildTimes, List<double> rasterTimes) {
    return methodChannel.invokeMethod('updatePerformanceMetrics', {
      'buildTimes': buildTimes,
      'rasterTimes': rasterTimes,
    });
  }
}

class MethodCallHandler {
  static const mapperError = {'_dd.mapper_error': 'mapper error'};

  final RumViewEventMapper? viewEventMapper;
  final RumActionEventMapper? actionEventMapper;
  final RumResourceEventMapper? resourceEventMapper;
  final RumErrorEventMapper? errorEventMapper;
  final RumLongTaskEventMapper? longTaskEventMapper;

  final InternalLogger internalLogger;

  MethodCallHandler({
    this.viewEventMapper,
    this.actionEventMapper,
    this.resourceEventMapper,
    this.errorEventMapper,
    this.longTaskEventMapper,
    required this.internalLogger,
  });

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'mapViewEvent':
        return _mapViewEvent(call);
      case 'mapActionEvent':
        return _mapActionEvent(call);
      case 'mapResourceEvent':
        return _mapResourceEvent(call);
      case 'mapErrorEvent':
        return _mapErrorEvent(call);
      case 'mapLongTaskEvent':
        return _mapLongTaskEvent(call);
    }

    throw MissingPluginException(
        'Could not find a method to call for ${call.method}');
  }

  Map<String, Object?>? _callMapper<T>(
    String mapperName,
    Map<dynamic, dynamic> encoded,
    T? Function(T)? mapper,
    Map<String, dynamic> Function(T) encode,
    T Function(Map<dynamic, dynamic>) decode,
  ) {
    try {
      if (mapper == null) {
        final st = StackTrace.current;
        internalLogger.sendToDatadog(
            '$mapperName called but no $mapperName is set,',
            st,
            'InternalDatadogError');
        return mapperError;
      }

      final event = decode(encoded);

      T? mappedEvent = event;
      try {
        mappedEvent = mapper(event);
        if (mappedEvent == null) {
          return null;
        }
      } catch (e) {
        internalLogger.error(
            '$mapperName threw an exception: ${e.toString()}.\nReturning unmapped event.');
        return mapperError;
      }

      final mappedJson = encode(mappedEvent);
      return mappedJson;
    } catch (e, st) {
      internalLogger.sendToDatadog('Error mapping view event: ${e.toString()}',
          st, e.runtimeType.toString());
    }

    // Return a special map which will indicate to native code something went wrong, and
    // we should send the unmodified event.
    return mapperError;
  }

  Map<Object, Object?>? _mapViewEvent(MethodCall call) {
    final viewEventJson = call.arguments['event'] as Map;
    return _callMapper<RumViewEvent>(
      'mapViewEvent',
      viewEventJson,
      viewEventMapper,
      (e) => e.toJson(),
      RumViewEvent.fromJson,
    );
  }

  Map<Object, Object?>? _mapActionEvent(MethodCall call) {
    final eventJson = call.arguments['event'] as Map;
    return _callMapper<RumActionEvent>(
      'mapActionEvent',
      eventJson,
      actionEventMapper,
      (e) => e.toJson(),
      RumActionEvent.fromJson,
    );
  }

  Map<Object, Object?>? _mapResourceEvent(MethodCall call) {
    final eventJson = call.arguments['event'] as Map;
    return _callMapper<RumResourceEvent>(
      'mapResourceEvent',
      eventJson,
      resourceEventMapper,
      (e) => e.toJson(),
      RumResourceEvent.fromJson,
    );
  }

  Map<Object, Object?>? _mapErrorEvent(MethodCall call) {
    final eventJson = call.arguments['event'] as Map;
    return _callMapper<RumErrorEvent>(
      'mapErrorEvent',
      eventJson,
      errorEventMapper,
      (e) => e.toJson(),
      RumErrorEvent.fromJson,
    );
  }

  Map<Object, Object?>? _mapLongTaskEvent(MethodCall call) {
    final eventJson = call.arguments['event'] as Map;
    return _callMapper<RumLongTaskEvent>(
      'mapLongTaskEvent',
      eventJson,
      longTaskEventMapper,
      (e) => e.toJson(),
      RumLongTaskEvent.fromJson,
    );
  }
}
