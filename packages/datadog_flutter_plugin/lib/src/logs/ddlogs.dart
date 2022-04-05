// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.
import 'package:uuid/uuid.dart';

import '../helpers.dart';
import '../internal_logger.dart';
import 'ddlogs_platform_interface.dart';

const uuid = Uuid();

class DdLogs {
  final InternalLogger _internalLogger;
  final String loggerHandle;

  DdLogs(this._internalLogger) : loggerHandle = uuid.v4();

  static DdLogsPlatform get _platform {
    return DdLogsPlatform.instance;
  }

  void debug(String message, [Map<String, Object?> context = const {}]) {
    wrap('logs.debug', _internalLogger, () {
      return _platform.debug(loggerHandle, message, context);
    });
  }

  void info(String message, [Map<String, Object?> context = const {}]) {
    wrap('logs.info', _internalLogger, () {
      return _platform.info(loggerHandle, message, context);
    });
  }

  void warn(String message, [Map<String, Object?> context = const {}]) {
    wrap('logs.warn', _internalLogger, () {
      return _platform.warn(loggerHandle, message, context);
    });
  }

  void error(String message, [Map<String, Object?> context = const {}]) {
    wrap('logs.error', _internalLogger, () {
      return _platform.error(loggerHandle, message, context);
    });
  }

  void addAttribute(String key, Object value) {
    wrap('logs.addAttribute', _internalLogger, () {
      return _platform.addAttribute(loggerHandle, key, value);
    });
  }

  void removeAttribute(String key) {
    wrap('logs.removeAttribute', _internalLogger, () {
      return _platform.removeAttribute(loggerHandle, key);
    });
  }

  void addTag(String key, [String? value]) {
    wrap('logs.addTag', _internalLogger, () {
      return _platform.addTag(loggerHandle, key, value);
    });
  }

  void removeTag(String tag) {
    wrap('logs.removeTag', _internalLogger, () {
      return _platform.removeTag(loggerHandle, tag);
    });
  }

  void removeTagWithKey(String key) {
    wrap('logs.removeTagWithKey', _internalLogger, () {
      return _platform.removeTagWithKey(loggerHandle, key);
    });
  }
}
