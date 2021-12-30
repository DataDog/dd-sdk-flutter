// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import 'ddtraces.dart';
import 'ddtraces_platform_interface.dart';

class DdTracesMethodChannel extends DdTracesPlatform {
  @visibleForTesting
  final MethodChannel methodChannel =
      const MethodChannel('datadog_sdk_flutter.traces');

  @override
  Future<DdSpan> startRootSpan(String operationName, Map<String, dynamic>? tags,
      DateTime? startTime) async {
    var result = await methodChannel.invokeMethod('startRootSpan', {
      'operationName': operationName,
      'tags': tags,
      'startTime': startTime?.millisecondsSinceEpoch
    });
    if (result is int) {
      return DdSpan(this, result);
    }
    // TODO: Failed to create span
    return DdSpan(this, 0);
  }

  @override
  Future<DdSpan> startSpan(String operationName, DdSpan? parentSpan,
      Map<String, dynamic>? tags, DateTime? startTime) async {
    var result = await methodChannel.invokeMethod('startSpan', {
      'operationName': operationName,
      'parentSpan': parentSpan?.handle,
      'tags': tags,
      'startTime': startTime?.millisecondsSinceEpoch
    });
    if (result is int) {
      return DdSpan(this, result);
    }
    // TODO: Failed to create span
    return DdSpan(this, 0);
  }

  // Span methods
  @override
  Future<void> spanSetActive(DdSpan span) {
    return methodChannel.invokeMethod('span.setActive', {
      'spanHandle': span.handle,
    });
  }

  @override
  Future<void> spanSetBaggageItem(DdSpan span, String key, String value) {
    return methodChannel.invokeMethod('span.setBaggageItem',
        {'spanHandle': span.handle, 'key': key, 'value': value});
  }

  @override
  Future<void> spanSetTag(DdSpan span, String key, dynamic value) {
    return methodChannel.invokeMethod(
        'span.setTag', {'spanHandle': span.handle, 'key': key, 'value': value});
  }

  @override
  Future<void> spanSetError(
      DdSpan span, String kind, String message, String? stack) {
    return methodChannel.invokeMethod('span.setError', {
      'spanHandle': span.handle,
      'kind': kind,
      'message': message,
      'stackTrace': stack
    });
  }

  @override
  Future<void> spanLog(DdSpan span, Map<String, Object?> fields) {
    return methodChannel.invokeMethod('span.log', {
      'spanHandle': span.handle,
      'fields': fields,
    });
  }

  @override
  Future<void> spanFinish(DdSpan span) {
    return methodChannel
        .invokeMethod('span.finish', {'spanHandle': span.handle});
  }
}
