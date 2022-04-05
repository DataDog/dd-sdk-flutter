// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'datadog_configuration.dart';
import 'datadog_sdk_platform_interface.dart';

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
      String? id, String? name, String? email, Map<String, dynamic> extraInfo) {
    return methodChannel.invokeMethod('setUserInfo',
        {'id': id, 'name': name, 'email': email, 'extraInfo': extraInfo});
  }

  @override
  Future<void> initialize(DdSdkConfiguration configuration,
      {LogCallback? logCallback}) async {
    if (logCallback != null) {
      methodChannel.setMethodCallHandler((call) {
        switch (call.method) {
          case 'logCallback':
            logCallback(call.arguments as String);
            break;
        }
        return Future.value();
      });
    }

    await methodChannel
        .invokeMethod('initialize', {'configuration': configuration.encode()});
  }

  @override
  Future<void> flushAndDeinitialize() {
    return methodChannel.invokeMethod('flushAndDeinitialize', {});
  }
}
