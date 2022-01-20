// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'ddlogs_platform_interface.dart';

import '../internal_logger.dart';

class DdLogs {
  final InternalLogger _logger;
  DdLogs(this._logger);

  static DdLogsPlatform get _platform {
    return DdLogsPlatform.instance;
  }

  Future<void> debug(String message,
      [Map<String, Object?> context = const {}]) async {
    try {
      await _platform.debug(message, context);
    } catch (e) {
      // TELEMETRY: Report this back to Datadog
      _logger.error(e.toString());
    }
  }

  Future<void> info(String message,
      [Map<String, Object?> context = const {}]) async {
    try {
      await _platform.info(message, context);
    } catch (e) {
      // TELEMETRY: Report this back to Datadog
      _logger.error(e.toString());
    }
  }

  Future<void> warn(String message,
      [Map<String, Object?> context = const {}]) async {
    try {
      await _platform.warn(message, context);
    } catch (e) {
      // TELEMETRY: Report this back to Datadog
      _logger.error(e.toString());
    }
  }

  Future<void> error(String message,
      [Map<String, Object?> context = const {}]) async {
    try {
      await _platform.error(message, context);
    } catch (e) {
      // TELEMETRY: Report this back to Datadog
      _logger.error(e.toString());
    }
  }

  Future<void> addAttribute(String key, Object value) async {
    try {
      await _platform.addAttribute(key, value);
    } on ArgumentError catch (e) {
      _logger.warn(InternalLogger.argumentWarning('logs.addAttribute', e));
    } catch (e) {
      // TELEMETRY: Report this back to Datadog
      _logger.error(e.toString());
    }
  }

  Future<void> removeAttribute(String key) async {
    try {
      await _platform.removeAttribute(key);
    } catch (e) {
      // TELEMETRY: Report this back to Datadog
      _logger.error(e.toString());
    }
  }

  Future<void> addTag(String key, [String? value]) async {
    try {
      await _platform.addTag(key, value);
    } catch (e) {
      // TELEMETRY: Report this back to Datadog
      _logger.error(e.toString());
    }
  }

  Future<void> removeTag(String tag) async {
    try {
      await _platform.removeTag(tag);
    } catch (e) {
      // TELEMETRY: Report this back to Datadog
      _logger.error(e.toString());
    }
  }

  Future<void> removeTagWithKey(String key) async {
    try {
      await _platform.removeTagWithKey(key);
    } catch (e) {
      // TELEMETRY: Report this back to Datadog
      _logger.error(e.toString());
    }
  }
}
