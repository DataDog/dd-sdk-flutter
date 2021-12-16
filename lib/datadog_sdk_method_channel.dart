// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import 'datadog_sdk.dart';
import 'datadog_sdk_platform_interface.dart';

class DatadogSdkMethodChannel extends DatadogSdkPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('datadog_sdk_flutter');

  @override
  Future<void> initialize(DdSdkConfiguration configuration) async {
    await methodChannel.invokeMethod(
        'DdSdk.initialize', {'configuration': configuration.encode()});
  }

  @override
  DdLogs get ddLogs => DdLogsMethodChannel(methodChannel);
}

class DdLogsMethodChannel extends DdLogs {
  final MethodChannel methodChannel;

  DdLogsMethodChannel(this.methodChannel);

  @override
  Future<void> debug(String message,
      [Map<String, Object?> context = const {}]) {
    return methodChannel
        .invokeMethod('DdLogs.debug', {'message': message, 'context': context});
  }

  @override
  Future<void> info(String message, [Map<String, Object?> context = const {}]) {
    return methodChannel
        .invokeMethod('DdLogs.info', {'message': message, 'context': context});
  }

  @override
  Future<void> warn(String message, [Map<String, Object?> context = const {}]) {
    return methodChannel
        .invokeMethod('DdLogs.warn', {'message': message, 'context': context});
  }

  @override
  Future<void> error(String message,
      [Map<String, Object?> context = const {}]) {
    return methodChannel
        .invokeMethod('DdLogs.error', {'message': message, 'context': context});
  }
}
