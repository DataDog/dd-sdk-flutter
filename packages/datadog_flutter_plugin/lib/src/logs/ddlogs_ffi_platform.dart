// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../datadog_flutter_plugin.dart';
import '../ffi/datadog_sdk_ffi_platform.dart';
import '../ffi/dd_sdk_cpp.dart';
import '../ffi/ffi_helpers.dart';
import 'ddlogs_platform_interface.dart';

class DdFfiLogsPlatform extends DdLogsPlatform {
  DatadogSdkFfiPlatform? _corePlatform;
  Pointer<dd_logging>? _logging;
  final Map<String, Pointer<dd_logger>> _logMap = {};

  @override
  Future<void> enable(
      DatadogSdk core, DatadogLoggingConfiguration config) async {
    _corePlatform = core.platform as DatadogSdkFfiPlatform;
    if (_corePlatform?.core case final core?) {
      _logging = _corePlatform?.dd.dd_logging_init(core);
      if (_logging == nullptr) {
        _logging = null;
      }
    }
  }

  @override
  Future<void> addGlobalAttribute(String key, Object value) async {
    if (_logging case final logging?) {
      using((arena) {
        final cKey = key.toNativeUtf8(allocator: arena);
        final cValue =
            valueToFfiAttribute(value, _corePlatform!.dd, arena, 'value');
        _corePlatform!.dd
            .dd_logging_add_attribute(logging, cKey.cast(), cValue);
      });
    }
  }

  @override
  Future<void> removeGlobalAttribute(String key) async {
    if (_logging case final logging?) {
      using((arena) {
        final cKey = key.toNativeUtf8(allocator: arena);
        _corePlatform!.dd.dd_logging_remove_attribute(logging, cKey.cast());
      });
    }
  }

  @override
  Future<void> deinitialize() async {
    if (_logging case final logging?) {
      _corePlatform!.dd.dd_logging_destroy(logging);
      _logging = null;
    }
  }

  @override
  Future<void> addAttribute(String loggerHandle, String key, Object value) {
    if (_logMap[loggerHandle] case final log?) {
      using((arena) {
        final cName = key.toNativeUtf8(allocator: arena);
        final cAttribute =
            valueToFfiAttribute(value, _corePlatform!.dd, arena, 'value');

        _corePlatform!.dd
            .dd_logger_add_attribute(log, cName.cast(), cAttribute);
      });
    }
    return Future.value();
  }

  @override
  Future<void> addTag(String loggerHandle, String tag, [String? value]) {
    // TODO:
    return Future.value();
  }

  @override
  Future<void> createLogger(
      String loggerHandle, DatadogLoggerConfiguration config) async {
    final logger = _corePlatform!.dd.dd_logger_create(_logging!, nullptr);
    if (logger != nullptr) {
      _logMap[loggerHandle] = logger;
    }
  }

  @override
  Future<void> destroyLogger(String loggerHandle) {
    if (_logMap[loggerHandle] case final logger?) {
      _corePlatform!.dd.dd_logger_destroy(logger);
      _logMap.remove(loggerHandle);
    }
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
    if (_logMap[loggerHandle] case final logger?) {
      using((arena) {
        final cMessage = message.toNativeUtf8(allocator: arena);
        final cAttributes = attributesToFfiAttribute(
            attributes, _corePlatform!.dd, arena, 'attributes');
        _corePlatform!.dd.dd_logger_log_obj(
          logger,
          level.toFfiEnum(),
          cMessage.cast(),
          cAttributes,
        );
      });
    }
    return Future.value();
  }

  @override
  Future<void> removeAttribute(String loggerHandle, String key) {
    if (_logMap[loggerHandle] case final logger?) {
      using((arena) {
        final cKey = key.toNativeUtf8(allocator: arena);
        _corePlatform!.dd.dd_logger_remove_attribute(logger, cKey.cast());
      });
    }
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

extension on LogLevel {
  int toFfiValue() {
    return toFfiEnum().value;
  }

  dd_log_level_t toFfiEnum() {
    switch (this) {
      case LogLevel.debug:
        return dd_log_level_t.DD_LOG_LEVEL_DEBUG;
      case LogLevel.info:
        return dd_log_level_t.DD_LOG_LEVEL_INFO;
      case LogLevel.notice:
        return dd_log_level_t.DD_LOG_LEVEL_NOTICE;
      case LogLevel.warning:
        return dd_log_level_t.DD_LOG_LEVEL_WARN;
      case LogLevel.error:
        return dd_log_level_t.DD_LOG_LEVEL_ERROR;
      case LogLevel.critical:
        return dd_log_level_t.DD_LOG_LEVEL_CRITICAL;
      case LogLevel.alert:
        return dd_log_level_t.DD_LOG_LEVEL_CRITICAL;
      case LogLevel.emergency:
        return dd_log_level_t.DD_LOG_LEVEL_CRITICAL;
    }
  }
}
