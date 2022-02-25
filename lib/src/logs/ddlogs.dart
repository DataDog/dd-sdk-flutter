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

  Future<void> debug(String message,
      [Map<String, Object?> context = const {}]) async {
    return wrap('logs.debug', _logger, () async {
      await _platform.debug(message, context);
    });
  }

  Future<void> info(String message,
      [Map<String, Object?> context = const {}]) async {
    return wrap('logs.info', _logger, () async {
      await _platform.info(message, context);
    });
  }

  Future<void> warn(String message,
      [Map<String, Object?> context = const {}]) async {
    return wrap('logs.warn', _logger, () async {
      await _platform.warn(message, context);
    });
  }

  Future<void> error(String message,
      [Map<String, Object?> context = const {}]) async {
    return wrap('logs.error', _logger, () async {
      await _platform.error(message, context);
    });
  }

  Future<void> addAttribute(String key, Object value) async {
    return wrap('logs.addAttribute', _logger, () async {
      await _platform.addAttribute(key, value);
    });
  }

  Future<void> removeAttribute(String key) async {
    return wrap('logs.removeAttribute', _logger, () async {
      await _platform.removeAttribute(key);
    });
  }

  Future<void> addTag(String key, [String? value]) async {
    return wrap('logs.addTag', _logger, () async {
      await _platform.addTag(key, value);
    });
  }

  Future<void> removeTag(String tag) async {
    return wrap('logs.removeTag', _logger, () async {
      await _platform.removeTag(tag);
    });
  }

  Future<void> removeTagWithKey(String key) async {
    return wrap('logs.removeTagWithKey', _logger, () async {
      await _platform.removeTagWithKey(key);
    });
  }
}
