// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:flutter/services.dart';

import 'internal_logger.dart';

typedef WrappedCall<T> = Future<T?> Function();

/// Wraps a call to a platform channel with common error handling and telemetry.
Future<T?> wrap<T>(
    String methodName, InternalLogger logger, WrappedCall<T> call) async {
  try {
    return await call();
  } on ArgumentError catch (e) {
    logger.warn(InternalLogger.argumentWarning(methodName, e));
  } on PlatformException catch (e) {
    logger.error('Datadog experienced a PlatformException - ${e.message}');
    logger.error(
        'This may be a bug in the Datadog SDK. Please report it to Datadog.');
    logger
        .sendToDatadog('Platform exception caught by wrap(): ${e.toString()}');
  }
  return null;
}
