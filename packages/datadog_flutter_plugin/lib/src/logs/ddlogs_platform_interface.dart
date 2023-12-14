// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../datadog_flutter_plugin.dart';
import 'ddlogs_method_channel.dart';

abstract class DdLogsPlatform extends PlatformInterface {
  DdLogsPlatform() : super(token: _token);

  static final Object _token = Object();

  static DdLogsPlatform _instance = DdLogsMethodChannel();

  static DdLogsPlatform get instance => _instance;

  static set instance(DdLogsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> enable(DatadogSdk core, DatadogLoggingConfiguration config);
  Future<void> deinitialize();

  Future<void> createLogger(
      String loggerHandle, DatadogLoggerConfiguration config);
  Future<void> destroyLogger(String loggerHandle);

  Future<void> log(
    String loggerHandle,
    LogLevel level,
    String message,
    String? errorMessage,
    String? errorKind,
    StackTrace? errorStackTrace,
    Map<String, Object?> attributes,
  );

  Future<void> addAttribute(String loggerHandle, String key, Object value);
  Future<void> removeAttribute(String loggerHandle, String key);
  Future<void> addTag(String loggerHandle, String tag, [String? value]);
  Future<void> removeTag(String loggerHandle, String tag);
  Future<void> removeTagWithKey(String loggerHandle, String key);
}
