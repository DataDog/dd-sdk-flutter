// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:jni/jni.dart';

import '../../datadog_flutter_plugin.dart';
import '../internal_logger.dart';
import '../rum/rum_mapper_proxy.dart';
import 'datadog_android_bridge.dart';
import 'json_helpers.dart';

typedef _MapperFunction = Map<String, dynamic>? Function(Map<String, dynamic>);

class AndroidRumEventMapper extends RumMapperProxy {
  final InternalLogger _internalLogger;

  AndroidRumEventMapper(DatadogRumConfiguration config, InternalLogger logger)
    : _internalLogger = logger,
      super(
        viewEventMapper: config.viewEventMapper,
        actionEventMapper: config.actionEventMapper,
        resourceEventMapper: config.resourceEventMapper,
        errorEventMapper: config.errorEventMapper,
        longTaskEventMapper: config.longTaskEventMapper,
      ) {
    final listener = DatadogRumEventMapper$EventMapper.implement(
      $DatadogRumEventMapper$EventMapper(
        mapViewEvent: (encoded) {
          // Map View Event is weird because it's the only one that doesn't allow returning null, so it has special handling
          final decoded = safeDecodeJavaJson(encoded, _internalLogger);
          if (decoded == null) return encoded;

          final mapped = mapViewEvent(decoded);
          return safeEncodeJavaJson(
                mapped,
                _internalLogger,
                fallback: encoded,
              ) ??
              encoded;
        },
        mapActionEvent: (encoded) => _callMapper(encoded, mapActionEvent),
        mapResourceEvent: (encoded) => _callMapper(encoded, mapResourceEvent),
        mapErrorEvent: (encoded) => _callMapper(encoded, mapErrorEvent),
        mapLongTaskEvent: (encoded) => _callMapper(encoded, mapLongTaskEvent),
      ),
    );

    DatadogRumPlugin.Companion.setRumEventMapper(listener);
  }

  JString? _callMapper(JString encoded, _MapperFunction mapper) {
    final decoded = safeDecodeJavaJson(encoded, _internalLogger);
    if (decoded == null) return encoded;

    final mapped = mapper(decoded);
    return safeEncodeJavaJson(mapped, _internalLogger, fallback: encoded);
  }
}
