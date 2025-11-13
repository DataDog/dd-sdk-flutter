// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../datadog_flutter_plugin.dart';
import 'ddrum_method_channel.dart';

abstract class DdRumPlatform extends PlatformInterface {
  DdRumPlatform() : super(token: _token);

  static final Object _token = Object();

  static DdRumPlatform _instance = DdRumMethodChannel();

  static DdRumPlatform get instance => _instance;

  static set instance(DdRumPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  String? get cachedSessionId;

  Future<void> enable(DatadogSdk core, DatadogRumConfiguration configuration);
  Future<void> deinitialize();

  Future<String?> getCurrentSessionId();

  Future<void> startView(
    DateTime timestamp,
    String key,
    String name,
    Map<String, Object?> attributes,
  );
  Future<void> stopView(
    DateTime timestamp,
    String key,
    Map<String, Object?> attributes,
  );
  Future<void> addTiming(DateTime timestamp, String name);
  Future<void> addViewLoadingTime(bool overwrite);

  Future<void> startResource(
    DateTime timestamp,
    String key,
    RumHttpMethod httpMethod,
    String url,
    Map<String, Object?> attributes,
  );
  Future<void> stopResource(
    DateTime timestamp,
    String key,
    int? statusCode,
    RumResourceType kind,
    int? size,
    Map<String, Object?> attributes,
  );
  Future<void> stopResourceWithError(
    DateTime timestamp,
    String key,
    Exception error,
    Map<String, Object?> attributes,
  );
  Future<void> stopResourceWithErrorInfo(
    DateTime timestamp,
    String key,
    String message,
    String type,
    Map<String, Object?> attributes,
  );

  Future<void> addError(
    DateTime timestamp,
    Object error,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes,
  );
  Future<void> addErrorInfo(
    DateTime timestamp,
    String message,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes,
  );

  Future<void> addAction(
    DateTime timestamp,
    RumActionType type,
    String name,
    Map<String, Object?> attributes,
  );
  Future<void> startAction(
    DateTime timestamp,
    RumActionType type,
    String name,
    Map<String, Object?> attributes,
  );
  Future<void> stopAction(
    DateTime timestamp,
    RumActionType type,
    String name,
    Map<String, Object?> attributes,
  );

  Future<void> addAttribute(String key, dynamic value);
  Future<void> removeAttribute(String key);
  Future<void> setInternalViewAttribute(String key, Object value);

  Future<void> addFeatureFlagEvaluation(String name, Object value);
  Future<void> stopSession();

  Future<void> reportLongTask(DateTime at, int durationMs);
  Future<void> updatePerformanceMetrics(
    List<double> buildTimes,
    List<double> rasterTimes,
  );
}
