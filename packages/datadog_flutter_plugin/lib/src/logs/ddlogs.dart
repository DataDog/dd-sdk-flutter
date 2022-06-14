// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.
import 'package:uuid/uuid.dart';

import '../../datadog_flutter_plugin.dart';
import '../helpers.dart';
import '../internal_logger.dart';
import 'ddlogs_platform_interface.dart';

const _uuid = Uuid();

/// An interface for sending logs to Datadog.
///
/// It allows you to create a specific context (automatic information, custom
/// attributes, tags) that will be embedded in all logs sent through this
/// logger.
///
/// You can have multiple loggers configured in your application, each with
/// their own settings.
class DdLogs {
  final InternalLogger _internalLogger;
  final Verbosity _reportingThreshold;

  final String loggerHandle;

  DdLogs(this._internalLogger, this._reportingThreshold)
      : loggerHandle = _uuid.v4();

  static DdLogsPlatform get _platform {
    return DdLogsPlatform.instance;
  }

  /// Sends a `debug` log message.
  ///
  /// You can provide additional attributes for this log message using the
  /// [attributes] parameter. Values passed into [attributes] must be supported by
  /// [StandardMessageCodec].
  void debug(String message, [Map<String, Object?> attributes = const {}]) {
    if (_reportingThreshold.index <= Verbosity.debug.index) {
      wrap('logs.debug', _internalLogger, attributes, () {
        return _platform.debug(loggerHandle, message, attributes);
      });
    }
  }

  /// Sends an `info` log message.
  ///
  /// You can provide additional attributes for this log message using the
  /// [attributes] parameter. Values passed into [attributes] must be supported by
  /// [StandardMessageCodec].
  void info(String message, [Map<String, Object?> attributes = const {}]) {
    if (_reportingThreshold.index <= Verbosity.info.index) {
      wrap('logs.info', _internalLogger, attributes, () {
        return _platform.info(loggerHandle, message, attributes);
      });
    }
  }

  /// Sends a `warn` log message.
  ///
  /// You can provide additional attributes for this log message using the
  /// [attributes] parameter. Values passed into [attributes] must be supported by
  /// [StandardMessageCodec].
  void warn(String message, [Map<String, Object?> attributes = const {}]) {
    if (_reportingThreshold.index <= Verbosity.warn.index) {
      wrap('logs.warn', _internalLogger, attributes, () {
        return _platform.warn(loggerHandle, message, attributes);
      });
    }
  }

  /// Sends an `error` log message.
  ///
  /// You can provide additional attributes for this log message using the
  /// [attributes] parameter. Values passed into [attributes] must be supported by
  /// [StandardMessageCodec].
  void error(String message, [Map<String, Object?> attributes = const {}]) {
    if (_reportingThreshold.index <= Verbosity.error.index) {
      wrap('logs.error', _internalLogger, attributes, () {
        return _platform.error(loggerHandle, message, attributes);
      });
    }
  }

  /// Add a custom attribute to all future logs sent by this logger.
  ///
  /// Values can be nested up to 10 levels deep. Keys using more than 10 levels
  /// will be sanitized by SDK.
  ///
  /// All values must be supported by [StandardMessageCodec].
  void addAttribute(String key, Object value) {
    wrap('logs.addAttribute', _internalLogger, {'value': value}, () {
      return _platform.addAttribute(loggerHandle, key, value);
    });
  }

  /// Remove a custom attribute from all future logs sent by this logger.
  ///
  /// Previous logs won't lose the attribute value associated with this [key] if
  /// they were created prior to this call.
  void removeAttribute(String key) {
    wrap('logs.removeAttribute', _internalLogger, null, () {
      return _platform.removeAttribute(loggerHandle, key);
    });
  }

  /// Add a tag to all future logs sent by this logger.
  ///
  /// The tag will take the form "key:value" or "key" if no value is provided.
  ///
  /// Tags must start with a letter and after that may contain the following
  /// characters: Alphanumerics, Underscores, Minuses, Colons, Periods, Slashes.
  /// Other special characters are converted to underscores.
  ///
  /// Tags must be lowercase, and can be at most 200 characters. If the tag you
  /// provide is longer, only the first 200 characters will be used.
  ///
  /// See also: [Defining Tags](https://docs.datadoghq.com/tagging/#defining-tags)
  void addTag(String key, [String? value]) {
    wrap('logs.addTag', _internalLogger, null, () {
      return _platform.addTag(loggerHandle, key, value);
    });
  }

  /// Remove a given [tag] from all future logs sent by this logger.
  ///
  /// Previous logs won't lose the this tag if they were created prior to this call.
  void removeTag(String tag) {
    wrap('logs.removeTag', _internalLogger, null, () {
      return _platform.removeTag(loggerHandle, tag);
    });
  }

  /// Remove all tags with the given [key] from all future logs sent by this logger.
  ///
  /// Previous logs won't lose the this tag if they were created prior to this call.
  void removeTagWithKey(String key) {
    wrap('logs.removeTagWithKey', _internalLogger, null, () {
      return _platform.removeTagWithKey(loggerHandle, key);
    });
  }
}
