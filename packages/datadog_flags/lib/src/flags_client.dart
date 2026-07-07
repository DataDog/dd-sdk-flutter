// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'evaluation_context.dart';
import 'flags_error.dart';

/// Evaluates feature flags for one current evaluation context.
///
/// Create separate clients for separate mobile subjects, such as logged-out and
/// logged-in users. Clients are local to the Dart isolate where they are
/// created and must be recreated in background isolates.
abstract interface class DatadogFlagsClient {
  /// Stable name assigned by [DatadogFlags.sharedClient].
  String get name;

  /// Fetches assignments for [context] and makes them available to evaluations.
  ///
  /// Evaluations made before initialization completes return their provided
  /// default value with a `providerNotReady` error.
  Future<void> initialize(
    FlagsEvaluationContext context,
  );

  /// Evaluates a boolean flag and returns details about the result.
  FlagDetails<bool> getBooleanDetails({
    required String key,
    required bool defaultValue,
  });

  /// Evaluates a string flag and returns details about the result.
  FlagDetails<String> getStringDetails({
    required String key,
    required String defaultValue,
  });

  /// Evaluates an integer flag and returns details about the result.
  FlagDetails<int> getIntegerDetails({
    required String key,
    required int defaultValue,
  });

  /// Evaluates a floating-point flag and returns details about the result.
  FlagDetails<double> getDoubleDetails({
    required String key,
    required double defaultValue,
  });

  /// Evaluates a JSON-compatible flag and returns details about the result.
  FlagDetails<Object?> getObjectDetails({
    required String key,
    required Object? defaultValue,
  });

  /// Clears this client's assignments from memory and persistent storage.
  Future<void> reset();

  /// Stops background work and sends any pending telemetry for this client.
  Future<void> shutdown();
}

/// Result of a typed flag evaluation.
class FlagDetails<T> {
  /// Flag key that was evaluated.
  final String key;

  /// Evaluated value, or the caller-provided default when evaluation fails.
  final T value;

  /// Variant name returned by the assignments service, when available.
  final String? variant;

  /// Provider-specific evaluation reason, when available.
  final String? reason;

  /// Programmatic error describing why the default value was returned.
  final FlagEvaluationError? error;

  /// Creates immutable details for a flag evaluation result.
  const FlagDetails({
    required this.key,
    required this.value,
    this.variant,
    this.reason,
    this.error,
  });
}
