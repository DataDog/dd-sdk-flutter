// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../datadog_flutter_plugin.dart';
import '../../datadog_internal.dart';
import 'ddlogs_platform_interface.dart';

class DdLogsMethodChannel extends DdLogsPlatform {
  @visibleForTesting
  final MethodChannel methodChannel =
      const MethodChannel('datadog_sdk_flutter.logs');

  DatadogSdk? _core;
  LogEventMapper? _logEventMapper;

  DdLogsMethodChannel() {
    if (ServicesBinding.rootIsolateToken != null) {
      methodChannel.setMethodCallHandler(_handleMethodCall);
    }
  }

  @override
  Future<void> enable(DatadogSdk core, DatadogLoggingConfiguration config) {
    // NOTE: This will break when / if we move to multiple Datadog SDK instances
    _core = core;
    _logEventMapper = config.eventMapper;
    return methodChannel.invokeMethod('enable', {
      'configuration': config.encode(),
    });
  }

  @override
  Future<void> addGlobalAttribute(String key, Object value) {
    return methodChannel.invokeMethod('addGlobalAttribute', {
      'key': key,
      'value': value,
    });
  }

  @override
  Future<void> removeGlobalAttribute(String key) {
    return methodChannel.invokeMethod('removeGlobalAttribute', {
      'key': key,
    });
  }

  @override
  Future<void> deinitialize() {
    _core = null;
    _logEventMapper = null;
    return methodChannel.invokeMethod('deinitialize', {});
  }

  @override
  Future<void> createLogger(
      String loggerHandle, DatadogLoggerConfiguration config) {
    return methodChannel.invokeMethod('createLogger', {
      'loggerHandle': loggerHandle,
      'configuration': config.encode(),
    });
  }

  @override
  Future<void> destroyLogger(String loggerHandle) {
    return methodChannel.invokeMethod('destroyLogger', {
      'loggerHandle': loggerHandle,
    });
  }

  @override
  Future<void> log(
    String loggerHandle,
    LogLevel level,
    String message,
    String? errorMessage,
    String? errorKind,
    StackTrace? errorStackTrace,
    Map<String, Object?> attributes,
  ) {
    if (errorStackTrace != null) {
      // Modify context to supply the source_type
      attributes = {
        ...attributes,
        DatadogPlatformAttributeKey.errorSourceType: 'flutter',
      };
    }
    return methodChannel.invokeMethod('log', {
      'loggerHandle': loggerHandle,
      'logLevel': level.toString(),
      'errorMessage': errorMessage,
      'errorKind': errorKind,
      'stackTrace': errorStackTrace?.toString(),
      'message': message,
      'context': attributes,
    });
  }

  @override
  Future<void> addAttribute(String loggerHandle, String key, Object value) {
    return methodChannel.invokeMethod('addAttribute', {
      'loggerHandle': loggerHandle,
      'key': key,
      'value': value,
    });
  }

  @override
  Future<void> addTag(String loggerHandle, String tag, [String? value]) {
    return methodChannel.invokeMethod('addTag', {
      'loggerHandle': loggerHandle,
      'tag': tag,
      'value': value,
    });
  }

  @override
  Future<void> removeAttribute(String loggerHandle, String key) {
    return methodChannel.invokeMethod('removeAttribute', {
      'loggerHandle': loggerHandle,
      'key': key,
    });
  }

  @override
  Future<void> removeTag(String loggerHandle, String tag) {
    return methodChannel.invokeMethod('removeTag', {
      'loggerHandle': loggerHandle,
      'tag': tag,
    });
  }

  @override
  Future<void> removeTagWithKey(String loggerHandle, String key) {
    return methodChannel.invokeMethod('removeTagWithKey', {
      'loggerHandle': loggerHandle,
      'key': key,
    });
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'mapLogEvent':
        return _mapLogEvent(call);
    }
  }

  Map<Object?, Object?>? _mapLogEvent(MethodCall call) {
    // This is the same list as in LogEvent.kt
    const reservedAttributes = [
      'status',
      'service',
      'message',
      'date',
      'logger',
      '_dd',
      'usr',
      'network',
      'error',
      'ddtags'
    ];

    try {
      final logEventJson = call.arguments['event'] as Map;
      if (_logEventMapper == null) {
        final st = StackTrace.current;
        _core?.internalLogger.sendToDatadog(
            'Log event mapper called but no logEventMapper is set,',
            st,
            'InternalDatadogError');
        return logEventJson;
      }
      final logEvent = LogEvent.fromJson(logEventJson);
      // Pull out any extra attributes
      for (final item in logEventJson.entries) {
        final key = item.key as String;
        if (!reservedAttributes.contains(key)) {
          logEvent.attributes[key] = item.value;
        }
      }

      LogEvent? mappedLogEvent = logEvent;
      try {
        mappedLogEvent = _logEventMapper?.call(logEvent);
        if (mappedLogEvent == null) {
          return null;
        }
      } catch (e) {
        // User error, return unmapped, but report
        _core?.internalLogger.error(
            'logEventMapper threw an exception: ${e.toString()}.\nReturning unmapped event.');
      }

      final mappedJson = mappedLogEvent!.toJson();
      for (final item in mappedLogEvent.attributes.entries) {
        // Put extra attributes back
        if (!reservedAttributes.contains(item.key)) {
          mappedJson[item.key] = item.value;
        }
      }
      return mappedJson;
    } catch (e, st) {
      _core?.internalLogger.sendToDatadog(
          'Error mapping log event: ${e.toString()}',
          st,
          e.runtimeType.toString());
    }

    // Return a special map which will indicate to native code something went wrong, and
    // we should send the unmodified event.
    return {'_dd.mapper_error': 'mapper error'};
  }
}
