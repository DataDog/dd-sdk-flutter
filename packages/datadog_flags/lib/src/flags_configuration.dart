// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'assignment_request_client.dart';
import 'datadog_flags_config.dart';
import 'flags_store.dart';

/// Runtime configuration for Datadog feature flag clients.
@immutable
final class DatadogFlagsConfiguration {
  /// Default interval for aggregating and sending flag evaluation telemetry.
  static const defaultEvaluationFlushInterval = Duration(seconds: 10);

  /// Smallest supported flag evaluation telemetry flush interval.
  static const minEvaluationFlushInterval = Duration(seconds: 1);

  /// Largest supported flag evaluation telemetry flush interval.
  static const maxEvaluationFlushInterval = Duration(seconds: 60);

  /// Default number of retries after the first assignment request attempt.
  static const defaultAssignmentRequestRetryCount = 0;

  /// Largest supported number of retries after the first request attempt.
  static const maxAssignmentRequestRetryCount = 10;

  /// Overrides the precompute assignments endpoint.
  final Uri? customFlagsEndpoint;

  /// Additional headers sent with precompute assignment requests.
  final Map<String, String>? customFlagsHeaders;

  /// Timeout for each precomputed assignment request.
  ///
  /// A value of [Duration.zero] disables the timeout. Negative values are
  /// rejected when an assignment request is made.
  final Duration assignmentRequestTimeout;

  /// Number of retries after a transient assignment request failure.
  ///
  /// Must be between zero and [maxAssignmentRequestRetryCount], inclusive.
  final int assignmentRequestRetryCount;

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
  /// When omitted, [DatadogFlags] creates and owns a default client. When
  /// [assignmentRequestHttpClient] is also provided, this client is used only for
  /// exposure and evaluation telemetry.
  final http.Client? httpClient;

  /// Fully configured HTTP client used only for assignment requests.
  ///
  /// When provided, this client is used verbatim and
  /// [assignmentRequestTimeout] and [assignmentRequestRetryCount] are not
  /// applied. Compose [withAssignmentRequestTimeout] and
  /// [withAssignmentRequestRetry] to add those policies explicitly. The caller
  /// owns this client and must close it after disabling [DatadogFlags].
  final http.Client? assignmentRequestHttpClient;

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
    this.assignmentRequestTimeout = Duration.zero,
    this.assignmentRequestRetryCount = defaultAssignmentRequestRetryCount,
    this.customExposureEndpoint,
    this.trackExposures = true,
    this.customEvaluationEndpoint,
    this.trackEvaluations = true,
    Duration evaluationFlushInterval = defaultEvaluationFlushInterval,
    this.httpClient,
    this.assignmentRequestHttpClient,
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
