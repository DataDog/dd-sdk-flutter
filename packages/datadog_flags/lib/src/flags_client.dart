// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'evaluation_context.dart';
import 'flags_error.dart';
import 'flags_client_event.dart';

/// Evaluates feature flags for one current evaluation context.
///
/// Create separate clients for separate mobile subjects, such as logged-out and
/// logged-in users. Clients are local to the Dart isolate where they are
/// created and must be recreated in background isolates.
abstract interface class DatadogFlagsClient {
  /// Stable name assigned by [DatadogFlags.sharedClient].
  String get name;

  /// Registers [callback] for this client's first accepted cache or network
  /// installation, including an empty configuration. Every registration receives
  /// the retained first event once, even if registered after later updates.
  /// Missing, invalid or rejected data does not complete this notification.
  ///
  /// Delivery always runs in a microtask, including late registrations. It does
  /// not wait for initialization or persistence to complete. Evaluations in the
  /// callback read current assignments, not a snapshot pinned to the event.
  /// Synchronous callback exceptions are isolated; asynchronous work and errors
  /// started by the callback belong to the application.
  ///
  /// Returns an idempotent unregister function. It releases the callback and
  /// suppresses delivery that has not started, including an already queued
  /// microtask. It cannot interrupt a running callback, clear the retained event
  /// or cancel initialization. Reset does not rearm or erase the first event.
  /// Pending callbacks remain until installation or explicit unregistration.
  /// Reacquire a shared client after SDK re-enable; registrations do not migrate.
  void Function() onFirstFlags(void Function(FlagsClientEvent) callback);

  /// Fetches assignments for [context] and makes them available to evaluations.
  ///
  /// The first call completes when initialization finishes or the configured
  /// initialization timeout expires. A timeout completes this future with
  /// [FlagsInitializationTimeoutException]. It does not cancel the assignment
  /// operation. A late successful response still makes assignments available.
  /// Synchronous work can block the Dart isolate, so the timeout can complete
  /// later than its configured wall-clock budget.
  /// If a later call supersedes the first call, the first call remains bounded
  /// by its original deadline. The later call does not use this timeout.
  ///
  /// Evaluations made before assignments are available return their provided
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
  ///
  /// Returns `CACHED` for a successful evaluation from an
  /// installed store snapshot until a network response replaces it.
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
