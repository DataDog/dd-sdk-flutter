// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:convert';

import '../datadog_configuration.dart';
import '../datadog_native_core_platform.dart';
import 'ddlog_event.dart';
import 'ddlogs_platform_interface.dart';

class DdLogsNativeCorePlatform extends DdLogsPlatform {
  final NativeCore core;
  final Map<String, _NativeLogger> _loggers = {};

  DdLogsNativeCorePlatform(this.core);

  @override
  Future<void> addAttribute(
      String loggerHandle, String key, Object value) async {
    _loggers[loggerHandle]?.addAttribute(key, value);
  }

  @override
  Future<void> addTag(String loggerHandle, String tag, [String? value]) async {
    _loggers[loggerHandle]?.addTag(tag, value);
  }

  @override
  Future<void> createLogger(
      String loggerHandle, LoggingConfiguration config) async {
    _loggers[loggerHandle] = _NativeLogger(loggerHandle, core, config);
  }

  @override
  Future<void> log(
      String loggerHandle,
      LogLevel level,
      String message,
      String? errorMessage,
      String? errorKind,
      StackTrace? errorStackTrace,
      Map<String, Object?> attributes) async {
    _loggers[loggerHandle]?.log(
        level, message, errorMessage, errorKind, errorStackTrace, attributes);
  }

  @override
  Future<void> removeAttribute(String loggerHandle, String key) async {
    _loggers[loggerHandle]?.removeAttribute(key);
  }

  @override
  Future<void> removeTag(String loggerHandle, String tag) async {
    _loggers[loggerHandle]?.removeTag(tag);
  }

  @override
  Future<void> removeTagWithKey(String loggerHandle, String key) async {
    _loggers[loggerHandle]?.removeTagsWithKey(key);
  }
}

class _NativeLogger {
  final String handle;
  final NativeCore core;
  final LoggingConfiguration configuration;

  final Map<String, Object> _attributes = {};
  final Set<String> _tags = {};

  _NativeLogger(this.handle, this.core, this.configuration);

  void addAttribute(String key, Object value) {
    _attributes[key] = value;
  }

  void removeAttribute(String key) {
    _attributes.remove(key);
  }

  void addTag(String tag, [String? value]) {
    if (value != null) {
      _tags.add('$tag:$value');
    } else {
      _tags.add(tag);
    }
  }

  void removeTag(String tag) {
    _tags.remove(tag);
  }

  void removeTagsWithKey(String key) {
    _tags.removeWhere((e) => e.startsWith('$key:'));
  }

  void log(
    LogLevel level,
    String message,
    String? errorMessage,
    String? errorKind,
    StackTrace? errorStackTrace,
    Map<String, Object?> attributes,
  ) {
    LogEventError? errorInfo;
    if (errorMessage != null || errorKind != null || errorStackTrace != null) {
      errorInfo = LogEventError(
        kind: errorKind,
        message: errorMessage,
        stack: errorStackTrace.toString(),
      );
    }
    final event = LogEvent(
      date: DateTime.timestamp().millisecondsSinceEpoch.toString(),
      status: LogStatus.info,
      message: message,
      error: errorInfo,
      service: 'com.datadog.test.service',
      logger: LogEventLoggerInfo(
        name: configuration.loggerName ?? 'default',
        version: '0.0.8',
      ),
      dd: LogEventDd(
        device: LogDevice(architecture: 'arm64'),
      ),
      ddtags: _tags.join(','),
    );
    final encoded = jsonEncode(event.toJson());
    core.sendMessage(CoreMessage(
      featureTarget: 'logs',
      contextChanges: {},
      messageData: encoded,
    ));
  }
}
