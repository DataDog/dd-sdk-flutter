// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'datadog_flags_config.dart';
import 'flags_client.dart';
import 'flags_store.dart';

/// Runtime configuration for Datadog feature flag clients.
@immutable
final class DatadogFlagsConfiguration {
  /// Default maximum time to wait for the first evaluation context.
  static const defaultInitializationTimeout = Duration(seconds: 5);

  /// Default interval for aggregating and sending flag evaluation telemetry.
  static const defaultEvaluationFlushInterval = Duration(seconds: 10);

  /// Smallest supported flag evaluation telemetry flush interval.
  static const minEvaluationFlushInterval = Duration(seconds: 1);

  /// Largest supported flag evaluation telemetry flush interval.
  static const maxEvaluationFlushInterval = Duration(seconds: 60);

  /// Overrides the precompute assignments endpoint.
  final Uri? customFlagsEndpoint;

  /// Additional headers sent with precompute assignment requests.
  final Map<String, String>? customFlagsHeaders;

  /// Maximum wall-clock time to wait for the first evaluation context.
  ///
  /// This value is one budget for the complete initialization operation. The
  /// SDK does not restart it for each stage. It includes loading stored
  /// assignments, encoding the request, fetching assignments, reading the
  /// response body, decoding JSON, storing assignments, and making the
  /// assignments available for evaluation. It does not change the HTTP client's
  /// timeout. The assignment operation continues after this timeout and can
  /// make assignments available when it completes.
  ///
  /// The timeout applies only to the first
  /// [DatadogFlagsClient.initialize] call for each client. A `null`, zero, or
  /// negative value disables the timeout. If a later call supersedes the first
  /// call, only the first call remains bounded by this timeout.
  final Duration? initializationTimeout;

  /// Overrides the exposure intake endpoint.
  final Uri? customExposureEndpoint;

  /// Whether successful evaluations should emit exposure telemetry.
  final bool trackExposures;

  /// Overrides the flag evaluation intake endpoint.
  final Uri? customEvaluationEndpoint;

  /// Whether evaluations should be aggregated and sent to intake.
  final bool trackEvaluations;

  final Duration _evaluationFlushInterval;

  /// HTTP client used for assignments and telemetry.
  ///
  /// When omitted, [DatadogFlags] creates and owns a default client.
  final http.Client? httpClient;

  /// Datadog organization, environment, and site configuration.
  final DatadogFlagsConfig? datadogConfig;

  /// Optional assignment store used to seed startup from the last known data.
  final DatadogFlagsStore? store;

  /// Clock used for timestamps in stored assignments and telemetry.
  final DateTime Function() dateProvider;

  /// Creates SDK runtime configuration.
  const DatadogFlagsConfiguration({
    this.customFlagsEndpoint,
    this.customFlagsHeaders,
    this.initializationTimeout = defaultInitializationTimeout,
    this.customExposureEndpoint,
    this.trackExposures = true,
    this.customEvaluationEndpoint,
    this.trackEvaluations = true,
    Duration evaluationFlushInterval = defaultEvaluationFlushInterval,
    this.httpClient,
    this.datadogConfig,
    this.store,
    this.dateProvider = DateTime.now,
  }) : _evaluationFlushInterval = evaluationFlushInterval;

  /// Flush interval coerced to the same 1s-60s bounds used by the iOS and
  /// Android Flags SDKs.
  Duration get evaluationFlushInterval {
    if (_evaluationFlushInterval < minEvaluationFlushInterval) {
      return minEvaluationFlushInterval;
    }
    if (_evaluationFlushInterval > maxEvaluationFlushInterval) {
      return maxEvaluationFlushInterval;
    }
    return _evaluationFlushInterval;
  }
}
