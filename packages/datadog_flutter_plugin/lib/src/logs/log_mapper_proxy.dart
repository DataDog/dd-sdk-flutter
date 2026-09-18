// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../datadog_flutter_plugin.dart';
import '../../datadog_internal.dart';
import '../android/android_log_event_mapper.dart';
import '../ios/ios_log_event_mapper.dart';

abstract class LogMapperProxy {
  // This is the same list as in LogEvent.kt
  static const reservedAttributes = {
    'env',
    'status',
    'service',
    'message',
    'date',
    'logger',
    '_dd',
    'usr',
    'network',
    'error',
    'ddtags',
  };

  final LogEventMapper? _logEventMapper;

  LogMapperProxy({required LogEventMapper? logEventMapper})
      : _logEventMapper = logEventMapper;

  Map<String, dynamic>? mapLogEvent(Map<String, dynamic> logEventJson) {
    if (_logEventMapper case final mapper?) {
      final logEvent = LogEvent.fromJson(logEventJson);
      // Pull out any extra attributes
      for (final item in logEventJson.entries) {
        final key = item.key;
        if (!reservedAttributes.contains(key)) {
          logEvent.attributes[key] = item.value;
        }
      }

      final mappedEvent = mapper(logEvent);
      if (mappedEvent == null) return null;

      final mappedJson = mappedEvent.toJson();
      for (final item in mappedEvent.attributes.entries) {
        // Put extra attributes back
        final keyRoot = item.key.split('.').first;
        if (!reservedAttributes.contains(keyRoot)) {
          mappedJson[item.key] = item.value;
        }
      }
      return mappedJson;
    }

    return logEventJson;
  }

  static LogMapperProxy? fromConfiguration(
    DatadogLoggingConfiguration config,
    InternalLogger logger,
  ) {
    if (kIsWeb) {
      logger.sendToDatadog(
        'Attempting to make LogMapperProxy on Web!',
        StackTrace.current,
        'InvalidOperation',
      );
    } else {
      if (Platform.isAndroid) {
        return AndroidLogEventMapper(config, logger);
      } else if (Platform.isIOS) {
        return IosLogEventMapper(config, logger);
      }
    }
    return null;
  }
}
