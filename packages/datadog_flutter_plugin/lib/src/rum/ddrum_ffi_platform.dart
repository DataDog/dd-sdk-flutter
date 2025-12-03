// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../datadog_flutter_plugin.dart';
import '../ffi/datadog_sdk_ffi_platform.dart';
import '../ffi/dd_sdk_cpp.dart';
import '../ffi/ffi_helpers.dart';
import 'ddrum_platform_interface.dart';

class DdRumFfiPlatform extends DdRumPlatform {
  DatadogSdkFfiPlatform? _corePlatform;
  Pointer<dd_rum>? _rum;

  @override
  String? get cachedSessionId => null;

  @override
  Future<String?> getCurrentSessionId() => Future.value(null);

  @override
  Future<void> addAttribute(String key, dynamic value) async {
    final platform = _corePlatform;
    final rum = _rum;
    if (platform == null || rum == null) return;

    using((arena) {
      final cKey = key.toNativeUtf8(allocator: arena);
      final cValue = valueToFfiAttribute(value, platform.dd, arena, 'value');

      platform.dd.dd_rum_add_attribute(rum, cKey.cast<Char>(), cValue);
    });
  }

  @override
  Future<void> setInternalViewAttribute(String key, value) => Future.value();

  @override
  Future<void> addError(
    DateTime timestamp,
    Object error,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes,
  ) {
    return Future.value();
  }

  @override
  Future<void> addErrorInfo(
    DateTime timestamp,
    String message,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes,
  ) {
    return Future.value();
  }

  @override
  Future<void> addFeatureFlagEvaluation(String name, Object value) {
    return Future.value();
  }

  @override
  Future<void> addTiming(DateTime timestamp, String name) {
    return Future.value();
  }

  @override
  Future<void> addViewLoadingTime(bool overwrite) {
    return Future.value();
  }

  @override
  Future<void> addAction(
    DateTime timestamp,
    RumActionType type,
    String name,
    Map<String, Object?> attributes,
  ) {
    return Future.value();
  }

  @override
  Future<void> enable(
      DatadogSdk sdkCore, DatadogRumConfiguration configuration) async {
    _corePlatform = sdkCore.platform as DatadogSdkFfiPlatform;
    final dd = _corePlatform?.dd;
    final core = _corePlatform?.core;

    if (dd != null && core != null) {
      using((arena) {
        final rumConfig = arena<dd_rum_config>();
        final cApplicationId =
            configuration.applicationId.toNativeUtf8(allocator: arena);
        dd.dd_rum_config_init(rumConfig, cApplicationId.cast());

        dd.dd_rum_config_set_session_sample_rate(
            rumConfig, configuration.sessionSamplingRate);

        _rum = dd.dd_rum_init(core, rumConfig);
      });
    }
  }

  @override
  Future<void> deinitialize() async {
    if (_rum case final rum?) {
      _corePlatform?.dd.dd_rum_destroy(rum);
      _rum = null;
    }
  }

  @override
  Future<void> removeAttribute(String key) async {
    final platform = _corePlatform;
    final rum = _rum;
    if (platform == null || rum == null) return;

    using((arena) {
      final cKey = key.toNativeUtf8(allocator: arena);

      platform.dd.dd_rum_remove_attribute(rum, cKey.cast<Char>());
    });
  }

  @override
  Future<void> reportLongTask(DateTime at, int durationMs) {
    return Future.value();
  }

  @override
  Future<void> startResource(
    DateTime timestamp,
    String key,
    RumHttpMethod httpMethod,
    String url,
    Map<String, Object?> attributes,
  ) {
    return Future.value();
  }

  @override
  Future<void> startAction(
    DateTime timestamp,
    RumActionType type,
    String name,
    Map<String, Object?> attributes,
  ) {
    return Future.value();
  }

  @override
  Future<void> startView(
    DateTime timestamp,
    String key,
    String name,
    Map<String, Object?> attributes,
  ) async {
    final platform = _corePlatform;
    final rum = _rum;
    if (platform == null || rum == null) return;

    using((arena) {
      final cKey = key.toNativeUtf8(allocator: arena);
      final cName = name.toNativeUtf8(allocator: arena);
      final cAttributes = attributesToFfiAttribute(
          attributes, platform.dd, arena, 'attributes');
      platform.dd.dd_rum_start_view_obj(
          rum, cKey.cast<Char>(), cName.cast<Char>(), cAttributes);
    });
  }

  @override
  Future<void> stopResource(
    DateTime timestamp,
    String key,
    int? statusCode,
    RumResourceType kind,
    int? size,
    Map<String, Object?> attributes,
  ) {
    return Future.value();
  }

  @override
  Future<void> stopResourceWithError(
    DateTime timestamp,
    String key,
    Exception error,
    Map<String, Object?> attributes,
  ) {
    return Future.value();
  }

  @override
  Future<void> stopResourceWithErrorInfo(
    DateTime timestamp,
    String key,
    String message,
    String type,
    Map<String, Object?> attributes,
  ) {
    return Future.value();
  }

  @override
  Future<void> stopSession() async {
    final platform = _corePlatform;
    final rum = _rum;
    if (platform == null || rum == null) return;

    platform.dd.dd_rum_stop_session(rum);
  }

  @override
  Future<void> stopAction(
    DateTime timestamp,
    RumActionType type,
    String name,
    Map<String, Object?> attributes,
  ) {
    return Future.value();
  }

  @override
  Future<void> stopView(
    DateTime timestamp,
    String key,
    Map<String, Object?> attributes,
  ) async {
    final platform = _corePlatform;
    final rum = _rum;
    if (platform == null || rum == null) return;

    using((arena) {
      final cKey = key.toNativeUtf8(allocator: arena);
      final cAttributes = attributesToFfiAttribute(
          attributes, platform.dd, arena, 'attributes');
      platform.dd.dd_rum_stop_view_obj(rum, cKey.cast<Char>(), cAttributes);
    });
  }

  @override
  Future<void> updatePerformanceMetrics(
    List<double> buildTimes,
    List<double> rasterTimes,
  ) {
    return Future.value();
  }

  @override
  Future<void> failFeatureOperation(
      DateTime timestamp,
      String name,
      String? operationKey,
      RumFeatureOperationFailureReason failureReason,
      Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> startFeatureOperation(DateTime timestamp, String name,
      String? operationKey, Map<String, Object?> attributes) {
    return Future.value();
  }

  @override
  Future<void> succeedFeatureOperation(DateTime timestamp, String name,
      String? operationKey, Map<String, Object?> attributes) {
    return Future.value();
  }
}
