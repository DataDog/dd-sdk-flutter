// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../datadog_flutter_plugin.dart';
import 'ddlogs_ffi_platform.dart';
import 'ddlogs_method_channel.dart';
import 'ddlogs_noop_platform.dart';

abstract class DdLogsPlatform extends PlatformInterface {
  DdLogsPlatform() : super(token: _token);

  static final Object _token = Object();

  static DdLogsPlatform _instance = _createDefaultInstance();

  static DdLogsPlatform get instance => _instance;

  static set instance(DdLogsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  static DdLogsPlatform _createDefaultInstance() {
    if (!kIsWeb) {
      if (Platform.isLinux || Platform.isWindows) {
        return DdFfiLogsPlatform();
      }
      if (Platform.isAndroid || Platform.isIOS) {
        return DdLogsMethodChannel();
      }
    }
    return DdNoOpLogsPlatform();
  }

  Future<void> enable(DatadogSdk core, DatadogLoggingConfiguration config);
  Future<void> deinitialize();

  Future<void> addGlobalAttribute(String key, Object value);
  Future<void> removeGlobalAttribute(String key);

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
