// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import '../helpers.dart';
import '../internal_logger.dart';
import 'ddlogs_platform_interface.dart';

class DdLogs {
  final InternalLogger _logger;
  DdLogs(this._logger);

  static DdLogsPlatform get _platform {
    return DdLogsPlatform.instance;
  }

  void debug(String message, [Map<String, Object?> context = const {}]) {
    wrap('logs.debug', _logger, () {
      return _platform.debug(message, context);
    });
  }

  void info(String message, [Map<String, Object?> context = const {}]) {
    wrap('logs.info', _logger, () {
      return _platform.info(message, context);
    });
  }

  void warn(String message, [Map<String, Object?> context = const {}]) {
    wrap('logs.warn', _logger, () {
      return _platform.warn(message, context);
    });
  }

  void error(String message, [Map<String, Object?> context = const {}]) {
    wrap('logs.error', _logger, () {
      return _platform.error(message, context);
    });
  }

  void addAttribute(String key, Object value) {
    wrap('logs.addAttribute', _logger, () {
      return _platform.addAttribute(key, value);
    });
  }

  void removeAttribute(String key) {
    wrap('logs.removeAttribute', _logger, () {
      return _platform.removeAttribute(key);
    });
  }

  void addTag(String key, [String? value]) {
    wrap('logs.addTag', _logger, () {
      return _platform.addTag(key, value);
    });
  }

  void removeTag(String tag) {
    wrap('logs.removeTag', _logger, () {
      return _platform.removeTag(tag);
    });
  }

  void removeTagWithKey(String key) {
    wrap('logs.removeTagWithKey', _logger, () {
      return _platform.removeTagWithKey(key);
    });
  }
}
