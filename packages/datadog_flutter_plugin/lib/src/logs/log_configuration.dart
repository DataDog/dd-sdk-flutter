// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:flutter/foundation.dart';

import 'ddlogs_platform_interface.dart';

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

  DatadogLoggingConfiguration({
    this.customEndpoint,
  });

  Map<String, Object?> encode() {
    return {
      'customEndpoint': customEndpoint,
    };
  }
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

  /// Console
  CustomConsoleLogFunction? customConsoleLogFunction;

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
    this.customConsoleLogFunction,
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
