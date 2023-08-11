// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'datadog_configuration.dart';
import 'datadog_sdk_platform_interface.dart';
import 'internal_logger.dart';
import 'logs/ddlog_event.dart';

class DatadogSdkMethodChannel extends DatadogSdkPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('datadog_sdk_flutter');

  @override
  Future<void> setSdkVerbosity(Verbosity verbosity) {
    return methodChannel
        .invokeMethod('setSdkVerbosity', {'value': verbosity.toString()});
  }

  @override
  Future<void> setTrackingConsent(TrackingConsent trackingConsent) {
    return methodChannel.invokeMethod(
        'setTrackingConsent', {'value': trackingConsent.toString()});
  }

  @override
  Future<void> setUserInfo(
      String? id, String? name, String? email, Map<String, Object?> extraInfo) {
    return methodChannel.invokeMethod('setUserInfo',
        {'id': id, 'name': name, 'email': email, 'extraInfo': extraInfo});
  }

  @override
  Future<void> addUserExtraInfo(Map<String, Object?> extraInfo) {
    return methodChannel.invokeMethod('addUserExtraInfo', {
      'extraInfo': extraInfo,
    });
  }

  @override
  Future<PlatformInitializationResult> initialize(
    DdSdkConfiguration configuration, {
    LogCallback? logCallback,
    required InternalLogger internalLogger,
  }) async {
    final callbackHandler = MethodCallHandler(
      logCallback: logCallback,
      logEventMapper: configuration.logEventMapper,
      internalLogger: internalLogger,
    );

    if (logCallback != null) {
      methodChannel.setMethodCallHandler(callbackHandler.handleMethodCall);
    }

    await methodChannel.invokeMethod<void>('initialize', {
      'configuration': configuration.encode(),
      'dartVersion': Platform.version,
      'setLogCallback': logCallback != null,
    });

    return const PlatformInitializationResult(logs: true, rum: true);
  }

  @override
  Future<AttachResponse?> attachToExisting() async {
    final channelResponse = await methodChannel
        .invokeMapMethod<String, Object?>(
            'attachToExisting', <String, Object?>{});

    AttachResponse? response;
    if (channelResponse != null) {
      response = AttachResponse.decode(channelResponse);
    }
    return response;
  }

  @override
  Future<void> flushAndDeinitialize() {
    return methodChannel
        .invokeMethod('flushAndDeinitialize', <String, Object?>{});
  }

  @override
  Future<void> sendTelemetryDebug(String message) {
    return methodChannel.invokeMethod('telemetryDebug', {'message': message});
  }

  @override
  Future<void> sendTelemetryError(String message, String? stack, String? kind) {
    return methodChannel.invokeMethod('telemetryError', {
      'message': message,
      'stack': stack,
      'kind': kind,
    });
  }

  @override
  Future<void> updateTelemetryConfiguration(String property, bool value) {
    return methodChannel.invokeMethod('updateTelemetryConfiguration', {
      'option': property,
      'value': value,
    });
  }

  Future<Object?> getInternalVar(String name) {
    return methodChannel.invokeMethod('getInternalVar', {'name': name});
  }
}

@visibleForTesting
class MethodCallHandler {
  final LogCallback? logCallback;
  final LogEventMapper? logEventMapper;
  final InternalLogger internalLogger;

  MethodCallHandler({
    this.logCallback,
    this.logEventMapper,
    required this.internalLogger,
  });

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'logCallback':
        logCallback?.call(call.arguments as String);
        return null;
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
      if (logEventMapper == null) {
        final st = StackTrace.current;
        internalLogger.sendToDatadog(
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
        mappedLogEvent = logEventMapper?.call(logEvent);
        if (mappedLogEvent == null) {
          return null;
        }
      } catch (e) {
        // User error, return unmapped, but report
        internalLogger.error(
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
      internalLogger.sendToDatadog('Error mapping log event: ${e.toString()}',
          st, e.runtimeType.toString());
    }

    // Return a special map which will indicate to native code something went wrong, and
    // we should send the unmodified event.
    return {'_dd.mapper_error': 'mapper error'};
  }
}
