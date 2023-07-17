// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import '../datadog_configuration.dart';
import '../internal_logger.dart';
import 'ddrum.dart';
import 'ddrum_platform_interface.dart';

class DdNoOpRumPlatform extends DdRumPlatform {
  @override
  Future<void> addAttribute(String key, value) => Future.value();

  @override
  Future<void> addError(
      Object error,
      RumErrorSource source,
      StackTrace? stackTrace,
      String? errorType,
      Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> addErrorInfo(
      String message,
      RumErrorSource source,
      StackTrace? stackTrace,
      String? errorType,
      Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> addFeatureFlagEvaluation(String name, Object value) {
    return Future.value();
  }

  @override
  Future<void> addTiming(String name) {
    return Future.value();
  }

  @override
  Future<void> addUserAction(
      RumUserActionType type, String name, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> initialize(
      RumConfiguration configuration, InternalLogger internalLogger) {
    return Future.value();
  }

  @override
  Future<void> removeAttribute(String key) => Future.value();

  @override
  Future<void> reportLongTask(DateTime at, int durationMs) {
    return Future.value();
  }

  @override
  Future<void> startResourceLoading(String key, RumHttpMethod httpMethod,
      String url, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> startUserAction(
      RumUserActionType type, String name, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> startView(
      String key, String name, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> stopResourceLoading(String key, int? statusCode,
      RumResourceType kind, int? size, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> stopResourceLoadingWithError(
      String key, Exception error, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> stopResourceLoadingWithErrorInfo(String key, String message,
      String type, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> stopSession() => Future.value();

  @override
  Future<void> stopUserAction(
      RumUserActionType type, String name, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> stopView(String key, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> updatePerformanceMetrics(
      List<double> buildTimes, List<double> rasterTimes) {
    return Future.value();
  }
}
