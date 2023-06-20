// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../datadog_flutter_plugin.dart';
import '../internal_logger.dart';
import 'ddrum_method_channel.dart';

typedef SessionStartedCallback = void Function(DdRumSessionInfo sessionId);

abstract class DdRumPlatform extends PlatformInterface {
  DdRumPlatform() : super(token: _token);

  static final Object _token = Object();

  static DdRumPlatform _instance = DdRumMethodChannel();

  static DdRumPlatform get instance => _instance;

  static set instance(DdRumPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  DdRumSessionInfo? get sessionInfo;
  SessionStartedCallback? sessionStarted;

  Future<void> initialize(
      RumConfiguration configuration, InternalLogger internalLogger);

  Future<void> startView(
      String key, String name, Map<String, Object?> attributes);
  Future<void> stopView(String key, Map<String, Object?> attributes);
  Future<void> addTiming(String name);

  Future<void> startResourceLoading(String key, RumHttpMethod httpMethod,
      String url, Map<String, Object?> attributes);
  Future<void> stopResourceLoading(String key, int? statusCode,
      RumResourceType kind, int? size, Map<String, Object?> attributes);
  Future<void> stopResourceLoadingWithError(
      String key, Exception error, Map<String, Object?> attributes);
  Future<void> stopResourceLoadingWithErrorInfo(
      String key, String message, String type, Map<String, Object?> attributes);

  Future<void> addError(
    Object error,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes,
  );
  Future<void> addErrorInfo(
    String message,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes,
  );

  Future<void> addUserAction(
      RumUserActionType type, String name, Map<String, Object?> attributes);
  Future<void> startUserAction(
      RumUserActionType type, String name, Map<String, Object?> attributes);
  Future<void> stopUserAction(
      RumUserActionType type, String name, Map<String, Object?> attributes);

  Future<void> addAttribute(String key, dynamic value);
  Future<void> removeAttribute(String key);

  Future<void> addFeatureFlagEvaluation(String name, Object value);
  Future<void> stopSession();

  Future<void> reportLongTask(DateTime at, int durationMs);
  Future<void> updatePerformanceMetrics(
      List<double> buildTimes, List<double> rasterTimes);
}
