// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datadog_configuration.dart';
import 'ddlogs_platform_interface.dart';

class DdLogsMethodChannel extends DdLogsPlatform {
  @visibleForTesting
  final MethodChannel methodChannel =
      const MethodChannel('datadog_sdk_flutter.logs');

  @override
  Future<void> createLogger(String loggerHandle, LoggingConfiguration config) {
    return methodChannel.invokeMethod('createLogger', {
      'loggerHandle': loggerHandle,
      'configuration': config.encode(),
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
      Map<String, Object?> attributes) {
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
}
