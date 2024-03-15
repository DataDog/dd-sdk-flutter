// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:flutter/foundation.dart';

import 'ddlogs.dart';

/// A function that allows you to modify or drop specific [LogEvent]s before
/// they are sent to Datadog.
///
/// The [LogEventMapper] can modify any mutable (non-final) properties in the
/// [LogEvent], or return null to drop the log entirely.
typedef LogEventMapper = LogEvent? Function(LogEvent event);

/// A function that allows you control Datadog's console log output. This function
/// is called instead of calling Flutter's default `print`, and does not effect what
/// is sent to Datadog.
typedef CustomConsoleLogFunction = void Function(
  LogLevel level,
  String message,
  String? errorMessage,
  String? errorKind,
  StackTrace? stackTrace,
  Map<String, Object?> attributes,
);

/// Configuration options for the Datadog Logging feature.
/// These options are common to all Datadog logs
class DatadogLoggingConfiguration {
  String? customEndpoint;

  /// A function that allows you to modify or drop specific [LogEvent]s
  /// before they are sent to Datadog.
  LogEventMapper? eventMapper;

  DatadogLoggingConfiguration({
    this.customEndpoint,
    this.eventMapper,
  });

  Map<String, Object?> encode() {
    return {
      'customEndpoint': customEndpoint,
      'attachLogMapper': eventMapper != null,
    };
  }
}

/// Print all logs to the console in the form "[level] message" when
/// [kDebugMode] is true.
void simpleConsolePrint(
  LogLevel level,
  String message,
  String? errorMessage,
  String? errorKind,
  StackTrace? stackTrace,
  Map<String, Object?> attributes,
) {
  if (kDebugMode) {
    print('[${level.name}] $message');
  }
}

/// Print all logs to the console above the given level in the form
/// "[level] message" when [kDebugMode] is true.
CustomConsoleLogFunction simpleConsolePrintForLevel(LogLevel level) {
  return ((inLevel, message, errorMessage, errorKind, stackTrace, attributes) {
    if (kDebugMode) {
      if (inLevel.index >= level.index) {
        print('[${inLevel.name}] $message');
      }
    }
  });
}

/// Configuration options for a Datadog Log. These options are set for an
/// individual [DatadogLogger] object
class DatadogLoggerConfiguration {
  /// The service name  (default value is set to application bundle identifier)
  String? service;

  /// Sets the name of the logger.
  ///
  /// This name will be set as the `logger.name` attribute attached to all logs
  /// sent to Datadog from this logger.
  String? name;

  /// Sets the level of logs that get sent to Datadog
  ///
  /// Logs below the configured threshold are not sent to Datadog, while logs at
  /// this threshold and above are.
  ///
  /// Defaults to [LogLevel.debug]
  LogLevel remoteLogThreshold;

  /// Enables the logs integration with RUM.
  ///
  /// If enabled, all the logs will be enriched with the current RUM View
  /// information and it will be possible to see all the logs sent during a
  /// specific View lifespan in the RUM Explorer.
  ///
  /// Defaults to `true`.
  bool bundleWithRumEnabled;

  /// Enables the logs integration with active span API from Tracing.
  ///
  /// If enabled, all the logs will be bundled with the `activeSpan` trace and
  /// it will be possible to see all the logs sent during that specific trace.
  ///
  /// Default to `true`.
  bool bundleWithTraceEnabled;

  /// Enriches logs with network connection info. This means: reachability
  /// status, connection type, mobile carrier name and many more will be added
  /// to each log.
  ///
  /// Defaults to `false`.
  bool networkInfoEnabled;

  /// Control what Datadog outputs to the debug console. Uses [simpleConsolePrint]
  /// by default, which prints logs all logs to the console in the form "[level] message".
  ///
  /// You can filter by level using [simpleConsolePrintForLevel].
  ///
  /// To disable console log output, set this option to `null`
  CustomConsoleLogFunction? customConsoleLogFunction = simpleConsolePrint;

  double _sampleRate = 100;

  /// The sampling rate for this logger.
  ///
  /// The sampling rate must be a value between `0.0` and `100.0`. A value of `0.0`
  /// means no logs will be processed, `100.0` means all logs will be processed.
  /// The default is `100.0`
  double get remoteSampleRate => _sampleRate;
  set remoteSampleRate(double value) =>
      _sampleRate = clampDouble(value, 0, 100);

  DatadogLoggerConfiguration({
    this.service,
    this.name,
    this.remoteLogThreshold = LogLevel.debug,
    this.bundleWithRumEnabled = true,
    this.bundleWithTraceEnabled = true,
    this.networkInfoEnabled = true,
    double remoteSampleRate = 100,
    this.customConsoleLogFunction = simpleConsolePrint,
  }) {
    this.remoteSampleRate = remoteSampleRate;
  }

  Map<String, Object?> encode() {
    return {
      'service': service,
      'name': name,
      'remoteLogThreshold': remoteLogThreshold.toString(),
      'bundleWithRumEnabled': bundleWithRumEnabled,
      'bundleWithTraceEnabled': bundleWithTraceEnabled,
      'networkInfoEnabled': networkInfoEnabled,
      'remoteSampleRate': remoteSampleRate,
    };
  }
}
