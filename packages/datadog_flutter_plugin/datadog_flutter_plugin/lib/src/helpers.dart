// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:async';

import 'package:flutter/services.dart';

import 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart'
    show InternalLogger;

typedef WrappedCall<T> = FutureOr<T?> Function();

bool _willHandleError(Object e) {
  return e is ArgumentError || e is PlatformException;
}

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
      'Platform exception caught by wrap($methodName): ${error.toString()}',
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
        _handleError(e, st, methodName, logger, attributes);
      }, test: _willHandleError);
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

extension DurationHelpers on Duration {
  /// The number of whole nanoseconds spanned by this [Duration].
  ///
  /// Note, Dart only has precision up to the microsecond level, so the last
  /// digits of this value will always be zero.
  int get inNanoseconds {
    return inMicroseconds * 1000;
  }
}
