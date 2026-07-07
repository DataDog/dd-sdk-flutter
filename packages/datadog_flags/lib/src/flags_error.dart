// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

/// Programmatic reason why a flag evaluation returned its default value.
enum FlagEvaluationError {
  /// The client has not finished initialization for the requested context.
  providerNotReady('PROVIDER_NOT_READY'),

  /// The requested flag key was not present in the assignment data.
  flagNotFound('FLAG_NOT_FOUND'),

  /// The requested flag type did not match the assigned value type.
  typeMismatch('TYPE_MISMATCH');

  /// OpenFeature-compatible error code.
  final String code;

  /// Creates an evaluation error with an OpenFeature-compatible [code].
  const FlagEvaluationError(this.code);
}

enum FlagsErrorType {
  networkError,
  invalidResponse,
  clientNotInitialized,
  invalidConfiguration,
}

final class FlagsException implements Exception {
  final FlagsErrorType type;
  final String message;
  final Object? cause;

  const FlagsException(this.type, this.message, {this.cause});

  factory FlagsException.networkError(String message, {Object? cause}) {
    return FlagsException(FlagsErrorType.networkError, message, cause: cause);
  }

  factory FlagsException.invalidResponse(String message, {Object? cause}) {
    return FlagsException(
      FlagsErrorType.invalidResponse,
      message,
      cause: cause,
    );
  }

  factory FlagsException.clientNotInitialized(
    String message, {
    Object? cause,
  }) {
    return FlagsException(
      FlagsErrorType.clientNotInitialized,
      message,
      cause: cause,
    );
  }

  factory FlagsException.invalidConfiguration(
    String message, {
    Object? cause,
  }) {
    return FlagsException(
      FlagsErrorType.invalidConfiguration,
      message,
      cause: cause,
    );
  }

  @override
  String toString() => 'FlagsException($type): $message';
}
