// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ddlogs_platform_interface.dart';

class DdLogsMethodChannel extends DdLogsPlatform {
  @visibleForTesting
  final MethodChannel methodChannel =
      const MethodChannel('datadog_sdk_flutter.logs');

  @override
  Future<void> debug(String message,
      [Map<String, Object?> context = const {}]) {
    return methodChannel
        .invokeMethod('debug', {'message': message, 'context': context});
  }

  @override
  Future<void> info(String message, [Map<String, Object?> context = const {}]) {
    return methodChannel
        .invokeMethod('info', {'message': message, 'context': context});
  }

  @override
  Future<void> warn(String message, [Map<String, Object?> context = const {}]) {
    return methodChannel
        .invokeMethod('warn', {'message': message, 'context': context});
  }

  @override
  Future<void> error(String message,
      [Map<String, Object?> context = const {}]) {
    return methodChannel
        .invokeMethod('error', {'message': message, 'context': context});
  }
}
