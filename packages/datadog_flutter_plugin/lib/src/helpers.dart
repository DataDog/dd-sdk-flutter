// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'internal_logger.dart';

typedef WrappedCall<T> = FutureOr<T?> Function();

// Returns true if the error was handled, false if the error should be re-thrown
bool _handleError(Object error, StackTrace stackTrace, String methodName,
    InternalLogger logger, Map<String, Object?>? serializedAttributes) {
  if (error is ArgumentError) {
    logger.warn(InternalLogger.argumentWarning(
        methodName, error, serializedAttributes));
    return true;
  } else if (error is PlatformException) {
    logger.error('Datadog experienced a PlatformException - ${error.message}');
    logger.error(
        'This may be a bug in the Datadog SDK. Please report it to Datadog.');
    logger.sendToDatadog(
      'Platform exception caught by wrap(): ${error.toString()}',
      stackTrace,
      'PlatformException',
    );
    return true;
  }

  return false;
}

/// Wraps a call to a platform channel with common error handling and telemetry.
void wrap(
  String methodName,
  InternalLogger logger,
  Map<String, Object?>? attributes,
  WrappedCall<void> call,
) {
  try {
    var result = call();
    if (result is Future) {
      result.catchError((dynamic e, StackTrace st) {
        if (!_handleError(e, st, methodName, logger, attributes)) {
          throw e;
        }
      });
    }
  } catch (e, st) {
    if (!_handleError(e, st, methodName, logger, attributes)) {
      rethrow;
    }
  }
}

/// Wraps a call to a platform channel that must return a value, with common
/// error handling and telemetry. If you do not need to get a value back from
/// your call, use [wrap] instead.
Future<T?> wrapAsync<T>(String methodName, InternalLogger logger,
    Map<String, Object?>? attributes, WrappedCall<T> call) async {
  T? result;
  try {
    result = await call();
  } catch (e, st) {
    if (!_handleError(e, st, methodName, logger, attributes)) {
      rethrow;
    }
  }

  return result;
}

@immutable
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

InvalidAttributeInfo? _checkInvalidValue(
    Object? value, String fullPropertyName) {
  if (!_isValidAttributeType(value)) {
    return InvalidAttributeInfo(fullPropertyName, value.runtimeType.toString());
  } else if (value is Map<Object, Object?>) {
    final foundAttribute = _findInvalidAttributeInMap(value, fullPropertyName);
    if (foundAttribute != null) {
      return foundAttribute;
    }
  } else if (value is List<Object?>) {
    final foundAttribute = _findInvalidAttributeInList(value, fullPropertyName);
    if (foundAttribute != null) {
      return foundAttribute;
    }
  }
  return null;
}

InvalidAttributeInfo? _findInvalidAttributeInList(
    List<Object?> attributeList, String parentPropertyName) {
  for (var i = 0; i < attributeList.length; ++i) {
    final fullPropertyName =
        parentPropertyName.isEmpty ? '[$i]' : '$parentPropertyName[$i]';
    final value = attributeList[i];
    final attributeInfo = _checkInvalidValue(value, fullPropertyName);
    if (attributeInfo != null) {
      return attributeInfo;
    }
  }

  return null;
}

InvalidAttributeInfo? _findInvalidAttributeInMap(
    Map<Object, Object?> attributeMap, String parentPropertyName) {
  for (final entry in attributeMap.entries) {
    final key = entry.key;
    if (!_isValidAttributeType(key)) {
      return InvalidAttributeInfo(
          'Key: $parentPropertyName.$key', key.runtimeType.toString());
    }

    final value = entry.value;
    final fullPropertyName = parentPropertyName.isEmpty
        ? entry.key.toString()
        : '$parentPropertyName.${entry.key}';
    final attributeInfo = _checkInvalidValue(value, fullPropertyName);
    if (attributeInfo != null) {
      return attributeInfo;
    }
  }
  return null;
}

InvalidAttributeInfo? findInvalidAttribute(Map<String, Object?> attributes,
    [String parentPropertyName = '']) {
  return _checkInvalidValue(attributes, parentPropertyName);
}

/// This allows a value of type T or T? to be treated as a value of type T?.
///
/// We use this so that APIs that have become non-nullable can still be used
/// with `!` and `?` to support older versions of Flutter.
T? ambiguate<T>(T? value) => value;
