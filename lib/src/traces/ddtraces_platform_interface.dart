// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ddtraces.dart';
import 'ddtraces_method_channel.dart';

abstract class DdTracesPlatform extends PlatformInterface {
  DdTracesPlatform() : super(token: _token);

  static final Object _token = Object();

  static DdTracesPlatform _instance = DdTracesMethodChannel();

  static DdTracesPlatform get instance => _instance;

  static set instance(DdTracesPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<DdSpan?> startSpan(String operationName, DdSpan? parentSpan,
      String? resourceName, Map<String, dynamic>? tags, DateTime? startTime);
  Future<DdSpan?> startRootSpan(String operationName, String? resourceName,
      Map<String, dynamic>? tags, DateTime? startTime);
  Future<Map<String, String>> getTracePropagationHeaders(DdSpan span);

  // Span methods
  Future<void> spanSetActive(DdSpan span);
  Future<void> spanSetBaggageItem(DdSpan span, String key, String value);
  Future<void> spanSetTag(DdSpan span, String key, Object value);
  Future<void> spanSetError(
      DdSpan span, String kind, String message, String? stack);
  Future<void> spanLog(DdSpan span, Map<String, Object?> fields);
  Future<void> spanFinish(DdSpan span);
}
