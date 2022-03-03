// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:async';

import 'package:flutter/services.dart';

import 'internal_logger.dart';

typedef WrappedCall<T> = FutureOr<T?> Function();

void _handleError(Object error, StackTrace stackTrace, String methodName,
    InternalLogger logger) {
  if (error is ArgumentError) {
    logger.warn(InternalLogger.argumentWarning(methodName, error));
  } else if (error is PlatformException) {
    logger.error('Datadog experienced a PlatformException - ${error.message}');
    logger.error(
        'This may be a bug in the Datadog SDK. Please report it to Datadog.');
    logger.sendToDatadog(
        'Platform exception caught by wrap(): ${error.toString()}');
  } else {
    throw error;
  }
}

/// Wraps a call to a platform channel with common error handling and telemetry.
void wrap(String methodName, InternalLogger logger, WrappedCall<void> call) {
  try {
    var result = call();
    if (result is Future) {
      result.catchError((e, st) => _handleError(e, st, methodName, logger));
    }
  } catch (e, st) {
    _handleError(e, st, methodName, logger);
  }
}

/// Wraps a call to a platform channel that must return a value, with common
/// error handling and telemetry. If you do not need to get a value back from
/// your call, use [wrap] instead.
Future<T?> wrapAsync<T>(
    String methodName, InternalLogger logger, WrappedCall<T> call) async {
  T? result;
  try {
    result = await call();
  } catch (e, st) {
    _handleError(e, st, methodName, logger);
  }

  return result;
}
