// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import '../../datadog_flutter_plugin.dart';
import 'ddrum_platform_interface.dart';

class DdNoOpRumPlatform extends DdRumPlatform {
  @override
  Future<String?> getCurrentSessionId() => Future.value(null);

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
  Future<void> addViewLoadingTime(bool overwrite) {
    return Future.value();
  }

  @override
  Future<void> addAction(
      RumActionType type, String name, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> enable(DatadogSdk core, DatadogRumConfiguration configuration) {
    return Future.value();
  }

  @override
  Future<void> deinitialize() {
    return Future.value();
  }

  @override
  Future<void> removeAttribute(String key) => Future.value();

  @override
  Future<void> reportLongTask(DateTime at, int durationMs) {
    return Future.value();
  }

  @override
  Future<void> startResource(String key, RumHttpMethod httpMethod, String url,
      Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> startAction(
      RumActionType type, String name, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> startView(
      String key, String name, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> stopResource(String key, int? statusCode, RumResourceType kind,
      int? size, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> stopResourceWithError(
      String key, Exception error, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> stopResourceWithErrorInfo(String key, String message,
      String type, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> stopSession() => Future.value();

  @override
  Future<void> stopAction(
      RumActionType type, String name, Map<String, Object?> attributes) {
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
