// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:flutter/foundation.dart';

import 'datadog_sdk_platform_interface.dart';

/// This class is used internally by the SDK to log issues to the client
/// developers. Note that all logging from the Flutter portions of the SDK are
/// disabled if kDebugMode is not set.
class InternalLogger {
  bool useEmoji = true;
  CoreLoggerLevel sdkVerbosity = CoreLoggerLevel.warn;

  static const _emojiMap = {
    CoreLoggerLevel.debug: '',
    CoreLoggerLevel.warn: '⚠️',
    CoreLoggerLevel.error: '🔥',
    CoreLoggerLevel.critical: '⛔️'
  };

  void debug(String message) => log(CoreLoggerLevel.debug, message);
  void warn(String message) => log(CoreLoggerLevel.warn, message);
  void error(String message) => log(CoreLoggerLevel.error, message);
  void critical(String message) => log(CoreLoggerLevel.critical, message);

  void log(CoreLoggerLevel verbosity, String message) {
    if (kDebugMode && verbosity.index >= sdkVerbosity.index) {
      final prefixString = useEmoji
          ? '[Datadog 🐶${_emojiMap[verbosity]} ]'
          : '[Datadog - ${verbosity.name}]';
      // ignore: avoid_print
      print('$prefixString $message');
    }
  }

  /// Send a log to the Datadog org, not to the customer's org. This feature is
  /// used mostly to track potential issues in the Datadog SDK. The rate at which
  /// data is sent to Datadog is set by [DatadogRumConfiguration.telemetrySampleRate]
  void sendToDatadog(String message, StackTrace? stack, String? kind) {
    DatadogSdkPlatform.instance
        .sendTelemetryError(message, stack?.toString(), kind);
  }

  // Standard error strings
  static String argumentWarning(String methodName, ArgumentError e,
      Map<String, Object?>? serializedAttributes) {
    var warning =
        'ArgumentError when calling $methodName: parameter ${e.message}.';
    if (serializedAttributes != null) {
      final badAttribute = findInvalidAttribute(serializedAttributes);
      if (badAttribute != null) {
        warning +=
            ' It looks like ${badAttribute.propertyName} is of type ${badAttribute.propertyType}, which is not supported.';
      }
    }
    return warning;
  }
}

class InvalidAttributeInfo {
  final String propertyName;
  final String propertyType;

  const InvalidAttributeInfo(this.propertyName, this.propertyType);
}

bool _isValidAttributeType(Object? value) {
  if (value == null) return true;
  if (value is int) return true;
  if (value is double) return true;
  if (value is bool) return true;
  if (value is String) return true;
  if (value is Map<Object, Object?>) return true;
  if (value is List<Object?>) return true;
  return false;
}

InvalidAttributeInfo? _checkInvalidValue(Object? value, String fullPropertyName) {
  if (!_isValidAttributeType(value)) {
    return InvalidAttributeInfo(fullPropertyName, value.runtimeType.toString());
  } else if (value is Map<Object, Object?>) {
    final found = _findInvalidAttributeInMap(value, fullPropertyName);
    if (found != null) return found;
  } else if (value is List<Object?>) {
    final found = _findInvalidAttributeInList(value, fullPropertyName);
    if (found != null) return found;
  }
  return null;
}

InvalidAttributeInfo? _findInvalidAttributeInList(
    List<Object?> list, String parentPropertyName) {
  for (var i = 0; i < list.length; ++i) {
    final fullPropertyName =
        parentPropertyName.isEmpty ? '[$i]' : '$parentPropertyName[$i]';
    final info = _checkInvalidValue(list[i], fullPropertyName);
    if (info != null) return info;
  }
  return null;
}

InvalidAttributeInfo? _findInvalidAttributeInMap(
    Map<Object, Object?> map, String parentPropertyName) {
  for (final entry in map.entries) {
    final key = entry.key;
    if (!_isValidAttributeType(key)) {
      return InvalidAttributeInfo(
          'Key: $parentPropertyName.$key', key.runtimeType.toString());
    }
    final fullPropertyName = parentPropertyName.isEmpty
        ? entry.key.toString()
        : '$parentPropertyName.${entry.key}';
    final info = _checkInvalidValue(entry.value, fullPropertyName);
    if (info != null) return info;
  }
  return null;
}

InvalidAttributeInfo? findInvalidAttribute(Map<String, Object?> attributes,
    [String parentPropertyName = '']) {
  return _checkInvalidValue(attributes, parentPropertyName);
}
