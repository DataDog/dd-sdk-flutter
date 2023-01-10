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
  Future<void> initialize(
      RumConfiguration configuration, InternalLogger internalLogger) async {
    final callbackHandler = MethodCallHandler(
      viewEventMapper: configuration.rumViewEventMapper,
      internalLogger: internalLogger,
    );

    methodChannel.setMethodCallHandler(callbackHandler.handleMethodCall);
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
  Future<void> startResourceLoading(
    String key,
    RumHttpMethod httpMethod,
    String url, [
    Map<String, Object?> attributes = const {},
  ]) {
    return methodChannel.invokeMethod('startResourceLoading', {
      'key': key,
      'httpMethod': httpMethod.toString(),
      'url': url,
      'attributes': attributes
    });
  }

  @override
  Future<void> stopResourceLoading(
      String key, int? statusCode, RumResourceType kind,
      [int? size, Map<String, Object?>? attributes = const {}]) {
    return methodChannel.invokeMethod('stopResourceLoading', {
      'key': key,
      'statusCode': statusCode,
      'kind': kind.toString(),
      'size': size,
      'attributes': attributes
    });
  }

  @override
  Future<void> stopResourceLoadingWithError(String key, Exception error,
      [Map<String, Object?> attributes = const {}]) {
    return stopResourceLoadingWithErrorInfo(
        key, error.toString(), error.runtimeType.toString(), attributes);
  }

  @override
  Future<void> stopResourceLoadingWithErrorInfo(
    String key,
    String message,
    String type, [
    Map<String, Object?> attributes = const {},
  ]) {
    return methodChannel.invokeMethod('stopResourceLoadingWithError', {
      'key': key,
      'message': message,
      'type': type,
      'attributes': attributes,
    });
  }

  @override
  Future<void> addError(Object error, RumErrorSource source,
      StackTrace? stackTrace, Map<String, Object?> attributes) {
    return addErrorInfo(error.toString(), source, stackTrace, attributes);
  }

  @override
  Future<void> addErrorInfo(String message, RumErrorSource source,
      StackTrace? stackTrace, Map<String, Object?> attributes) {
    return methodChannel.invokeMethod('addError', {
      'message': message,
      'source': source.toString(),
      'stackTrace': stackTrace?.toString(),
      'attributes': attributes
    });
  }

  @override
  Future<void> addUserAction(
      RumUserActionType type, String? name, Map<String, Object?> attributes) {
    return methodChannel.invokeMethod('addUserAction', {
      'type': type.toString(),
      'name': name,
      'attributes': attributes,
    });
  }

  @override
  Future<void> startUserAction(
      RumUserActionType type, String name, Map<String, Object?> attributes) {
    return methodChannel.invokeMethod('startUserAction',
        {'type': type.toString(), 'name': name, 'attributes': attributes});
  }

  @override
  Future<void> stopUserAction(
      RumUserActionType type, String name, Map<String, Object?> attributes) {
    return methodChannel.invokeMethod('stopUserAction',
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
  final InternalLogger internalLogger;

  MethodCallHandler({this.viewEventMapper, required this.internalLogger});

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'mapViewEvent':
        return _mapViewEvent(call);
    }
  }

  Map<Object?, Object?>? _mapViewEvent(MethodCall call) {
    try {
      if (viewEventMapper == null) {
        final st = StackTrace.current;
        internalLogger.sendToDatadog(
            'Log event mapper called but no logEventMapper is set,',
            st,
            'InternalDatadogError');
        return mapperError;
      }

      final viewEventJson = call.arguments['event'] as Map;
      final viewEvent = RumViewEvent.fromJson(viewEventJson);

      RumViewEvent? mappedViewEvent = viewEvent;
      try {
        mappedViewEvent = viewEventMapper?.call(viewEvent);
        if (mappedViewEvent == null) {
          return null;
        }
      } catch (e) {
        internalLogger.error(
            'viewEventMapper threw an exception: ${e.toString()}.\nReturning unmapped event.');
        return mapperError;
      }

      final mappedJson = mappedViewEvent.toJson();
      return mappedJson;
    } catch (e, st) {
      internalLogger.sendToDatadog('Error mapping view event: ${e.toString()}',
          st, e.runtimeType.toString());
    }

    // Return a special map which will indicate to native code something went wrong, and
    // we should send the unmodified event.
    return mapperError;
  }
}
