// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import '../../datadog_flutter_plugin.dart';
import 'ddlogs_platform_interface.dart';

class DdNoOpLogsPlatform extends DdLogsPlatform {
  @override
  Future<void> enable(DatadogSdk core, DatadogLoggingConfiguration config) {
    return Future.value();
  }

  @override
  Future<void> deinitialize() {
    return Future.value();
  }

  @override
  Future<void> addAttribute(String loggerHandle, String key, Object value) {
    return Future.value();
  }

  @override
  Future<void> addTag(String loggerHandle, String tag, [String? value]) {
    return Future.value();
  }

  @override
  Future<void> createLogger(
      String loggerHandle, DatadogLoggerConfiguration config) {
    return Future.value();
  }

  @override
  Future<void> destroyLogger(String loggerHandle) {
    return Future.value();
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
    return Future.value();
  }

  @override
  Future<void> removeAttribute(String loggerHandle, String key) {
    return Future.value();
  }

  @override
  Future<void> removeTag(String loggerHandle, String tag) {
    return Future.value();
  }

  @override
  Future<void> removeTagWithKey(String loggerHandle, String key) {
    return Future.value();
  }
}
