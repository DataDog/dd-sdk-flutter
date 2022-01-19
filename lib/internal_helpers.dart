// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'internal_logger.dart';

typedef WrappedCall<T> = Future<T?> Function();

/// Wraps a call to a platform channel with common error handling and telemetry.
Future<T?> wrap<T>(
    String methodName, InternalLogger logger, WrappedCall<T> call) async {
  try {
    return await call();
  } on ArgumentError catch (e) {
    logger.warn(InternalLogger.argumentWarning(methodName, e));
  } catch (e) {
    // TELEMETRY: Report this back to Datadog
    logger.error(e.toString());
  }
  return null;
}
