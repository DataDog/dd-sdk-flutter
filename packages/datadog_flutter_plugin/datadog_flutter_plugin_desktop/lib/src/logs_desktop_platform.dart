// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi' as ffi;

import 'package:datadog_flutter_plugin_platform_interface/datadog_flutter_plugin_platform_interface.dart';
import 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart';
import 'package:ffi/ffi.dart';

import 'attribute_builder.dart';
import 'ffi_bindings.dart';
import 'native_char.dart';

class DdLogsDesktopPlatform extends DdLogsPlatform {
  final DdSdkFfi _sdk;
  // dd_logging_init must be called before dd_core_start, so the pointer is
  // provided here already initialized from DatadogDesktopPlatform.initialize().
  ffi.Pointer<dd_logging>? _logging;
  final Map<String, ffi.Pointer<dd_logger>> _loggers = {};

  DdLogsDesktopPlatform(this._sdk, ffi.Pointer<dd_logging> logging)
    : _logging = logging;

  @override
  Future<void> enable(
    InternalLogger logger,
    DatadogLoggingConfiguration config,
  ) async {
    // Feature was initialized in DatadogDesktopPlatform.initialize() before dd_core_start.
    // customEndpoint must be set on the core config before dd_core_start, not here.
  }

  @override
  Future<void> deinitialize() async {
    for (final logger in _loggers.values) {
      _sdk.dd_logger_destroy(logger);
    }
    _loggers.clear();
    final logging = _logging;
    if (logging != null) {
      _sdk.dd_logging_destroy(logging);
      _logging = null;
    }
  }

  @override
  Future<void> addGlobalAttribute(String key, Object value) async {
    final logging = _logging;
    if (logging == null) return;
    using((arena) {
      _sdk.dd_logging_add_attribute(
        logging,
        key.toNativeChar(allocator: arena),
        buildSingleAttr(value, arena, _sdk),
      );
    });
  }

  @override
  Future<void> removeGlobalAttribute(String key) async {
    final logging = _logging;
    if (logging == null) return;
    using((arena) {
      _sdk.dd_logging_remove_attribute(
        logging,
        key.toNativeChar(allocator: arena),
      );
    });
  }

  @override
  Future<void> createLogger(
    String loggerHandle,
    DatadogLoggerConfiguration config,
  ) async {
    final logging = _logging;
    if (logging == null) return;
    using((arena) {
      final cfg = arena<dd_logger_config>();
      _sdk.dd_logger_config_init(cfg);

      if (config.service != null) {
        _sdk.dd_logger_config_set_service(
          cfg,
          config.service!.toNativeChar(allocator: arena),
        );
      }
      if (config.name != null) {
        _sdk.dd_logger_config_set_name(
          cfg,
          config.name!.toNativeChar(allocator: arena),
        );
      }

      _sdk.dd_logger_config_set_remote_sample_rate(
        cfg,
        config.remoteSampleRate.toDouble(),
      );
      _sdk.dd_logger_config_set_remote_log_threshold(
        cfg,
        _logLevelToC(config.remoteLogThreshold),
      );
      _sdk.dd_logger_config_set_enrich_with_rum_context(
        cfg,
        config.bundleWithRumEnabled,
      );

      _loggers[loggerHandle] = _sdk.dd_logger_create(logging, cfg);
    });
  }

  @override
  Future<void> destroyLogger(String loggerHandle) async {
    final logger = _loggers.remove(loggerHandle);
    if (logger != null) _sdk.dd_logger_destroy(logger);
  }

  @override
  Future<void> log(
    String loggerHandle,
    LogLevel level,
    String message,
    String? errorMessage,
    String? errorKind,
    StackTrace? errorStackTrace,
    Map<String, Object?> attributes,
  ) async {
    final logger = _loggers[loggerHandle];
    if (logger == null) return;

    using((arena) {
      final msgPtr = message.toNativeChar(allocator: arena);
      final hasError =
          errorMessage != null || errorKind != null || errorStackTrace != null;

      // Mirror iOS/Android: tag the error source as 'flutter' when a stack trace is present.
      final enrichedAttrs = errorStackTrace != null
          ? {
              DatadogPlatformAttributeKey.errorSourceType: 'flutter',
              ...attributes,
            }
          : attributes;
      final attrs = buildAttrObject(enrichedAttrs, arena, _sdk);

      if (hasError) {
        final err = arena<dd_log_error>();
        err.ref.message = errorMessage.toNativeChar(allocator: arena);
        err.ref.kind = errorKind.toNativeChar(allocator: arena);
        err.ref.stack =
            errorStackTrace?.toString().toNativeChar(allocator: arena) ??
            ffi.nullptr;
        _sdk.dd_logger_log(logger, _logLevelToC(level), msgPtr, err, attrs);
      } else {
        _sdk.dd_logger_log(
          logger,
          _logLevelToC(level),
          msgPtr,
          ffi.nullptr,
          attrs,
        );
      }
    });
  }

  @override
  Future<void> addAttribute(
    String loggerHandle,
    String key,
    Object value,
  ) async {
    final logger = _loggers[loggerHandle];
    if (logger == null) return;
    using((arena) {
      _sdk.dd_logger_add_attribute(
        logger,
        key.toNativeChar(allocator: arena),
        buildSingleAttr(value, arena, _sdk),
      );
    });
  }

  @override
  Future<void> removeAttribute(String loggerHandle, String key) async {
    final logger = _loggers[loggerHandle];
    if (logger == null) return;
    using((arena) {
      _sdk.dd_logger_remove_attribute(
        logger,
        key.toNativeChar(allocator: arena),
      );
    });
  }

  @override
  Future<void> addTag(String loggerHandle, String tag, [String? value]) async {
    final logger = _loggers[loggerHandle];
    if (logger == null) return;
    using((arena) {
      if (value != null) {
        _sdk.dd_logger_add_tag_kv(
          logger,
          tag.toNativeChar(allocator: arena),
          value.toNativeChar(allocator: arena),
        );
      } else {
        _sdk.dd_logger_add_tag(logger, tag.toNativeChar(allocator: arena));
      }
    });
  }

  @override
  Future<void> removeTag(String loggerHandle, String tag) async {
    final logger = _loggers[loggerHandle];
    if (logger == null) return;
    using((arena) {
      _sdk.dd_logger_remove_tag(logger, tag.toNativeChar(allocator: arena));
    });
  }

  @override
  Future<void> removeTagWithKey(String loggerHandle, String key) async {
    final logger = _loggers[loggerHandle];
    if (logger == null) return;
    using((arena) {
      _sdk.dd_logger_remove_tags_with_key(
        logger,
        key.toNativeChar(allocator: arena),
      );
    });
  }

  int _logLevelToC(LogLevel level) {
    switch (level) {
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
      case LogLevel.alert:
      case LogLevel.emergency:
        return dd_log_level_t.DD_LOG_LEVEL_CRITICAL;
    }
  }
}
