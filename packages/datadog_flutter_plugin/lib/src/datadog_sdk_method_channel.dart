// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../datadog_flutter_plugin.dart';
import 'datadog_sdk_platform_interface.dart';
import 'internal_logger.dart';

class DatadogSdkMethodChannel extends DatadogSdkPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('datadog_sdk_flutter');

  @override
  Future<void> setSdkVerbosity(CoreLoggerLevel verbosity) {
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
    DatadogConfiguration configuration,
    TrackingConsent trackingConsent, {
    LogCallback? logCallback,
    required InternalLogger internalLogger,
  }) async {
    final callbackHandler = MethodCallHandler(
      logCallback: logCallback,
    );

    if (logCallback != null) {
      methodChannel.setMethodCallHandler(callbackHandler.handleMethodCall);
    }

    await methodChannel.invokeMethod<void>('initialize', {
      'configuration': configuration.encode(),
      'trackingConsent': trackingConsent.toString(),
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

    print('channelResponse $channelResponse');

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

  MethodCallHandler({
    this.logCallback,
  });

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'logCallback':
        logCallback?.call(call.arguments as String);
        return null;
    }
  }
}
