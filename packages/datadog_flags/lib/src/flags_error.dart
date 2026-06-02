// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

enum FlagEvaluationError {
  providerNotReady,
  flagNotFound,
  typeMismatch,
}

enum FlagsErrorType {
  networkError,
  invalidResponse,
  clientNotInitialized,
  invalidConfiguration,
}

class FlagsException implements Exception {
  final FlagsErrorType type;
  final String message;
  final Object? cause;

  const FlagsException(this.type, this.message, [this.cause]);

  factory FlagsException.networkError(String message, [Object? cause]) {
    return FlagsException(FlagsErrorType.networkError, message, cause);
  }

  factory FlagsException.invalidResponse(String message, [Object? cause]) {
    return FlagsException(FlagsErrorType.invalidResponse, message, cause);
  }

  factory FlagsException.clientNotInitialized(
    String message, [
    Object? cause,
  ]) {
    return FlagsException(FlagsErrorType.clientNotInitialized, message, cause);
  }

  factory FlagsException.invalidConfiguration(String message, [Object? cause]) {
    return FlagsException(FlagsErrorType.invalidConfiguration, message, cause);
  }

  @override
  String toString() => 'FlagsException($type): $message';
}
