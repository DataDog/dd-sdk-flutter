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
  Future<void> debug(String loggerHandle, String message,
      [Map<String, Object?> context = const {}]) {
    return methodChannel.invokeMethod('debug', {
      'loggerHandle': loggerHandle,
      'message': message,
      'context': context,
    });
  }

  @override
  Future<void> info(String loggerHandle, String message,
      [Map<String, Object?> context = const {}]) {
    return methodChannel.invokeMethod('info', {
      'loggerHandle': loggerHandle,
      'message': message,
      'context': context,
    });
  }

  @override
  Future<void> warn(String loggerHandle, String message,
      [Map<String, Object?> context = const {}]) {
    return methodChannel.invokeMethod('warn', {
      'loggerHandle': loggerHandle,
      'message': message,
      'context': context,
    });
  }

  @override
  Future<void> error(String loggerHandle, String message,
      [Map<String, Object?> context = const {}]) {
    return methodChannel.invokeMethod('error', {
      'loggerHandle': loggerHandle,
      'message': message,
      'context': context,
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
