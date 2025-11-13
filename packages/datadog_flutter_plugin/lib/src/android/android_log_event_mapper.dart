// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import '../../datadog_internal.dart';
import '../logs/log_mapper_proxy.dart';
import '../logs/logs.dart';
import 'datadog_android_bridge.dart';
import 'json_helpers.dart';

class AndroidLogEventMapper extends LogMapperProxy {
  final InternalLogger _internalLogger;

  AndroidLogEventMapper(
    DatadogLoggingConfiguration config,
    InternalLogger logger,
  ) : _internalLogger = logger,
      super(logEventMapper: config.eventMapper) {
    final listener = DatadogLogEventMapper$EventMapper.implement(
      $DatadogLogEventMapper$EventMapper(
        mapLogEvent: (encoded) {
          final decoded = safeDecodeJavaJson(encoded, _internalLogger);
          if (decoded == null) return encoded;

          final mapped = mapLogEvent(decoded);
          return safeEncodeJavaJson(mapped, _internalLogger, fallback: encoded);
        },
      ),
    );

    DatadogLogsPlugin.Companion.setLogsEventMapper(listener);
  }
}
