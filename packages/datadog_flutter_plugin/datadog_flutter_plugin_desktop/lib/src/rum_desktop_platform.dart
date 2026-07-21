// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi' as ffi;

import 'package:datadog_flutter_plugin_platform_interface/datadog_flutter_plugin_platform_interface.dart';
import 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart';
import 'package:ffi/ffi.dart';

import 'attribute_builder.dart';
import 'ffi_bindings.dart';
import 'native_char.dart';

class DdRumDesktopPlatform extends DdRumPlatform {
  final DdSdkFfi _sdk;
  // dd_rum_init must be called before dd_core_start, so the pointer is
  // provided here already initialized from DatadogDesktopPlatform.initialize().
  ffi.Pointer<dd_rum>? _rum;

  DdRumDesktopPlatform(this._sdk, ffi.Pointer<dd_rum> rum) : _rum = rum;

  @override
  String? get cachedSessionId => null;

  @override
  Future<void> enable(
      InternalLogger logger, DatadogRumConfiguration configuration) async {
    // Feature was initialized in DatadogDesktopPlatform.initialize() before dd_core_start.
  }

  @override
  Future<void> deinitialize() async {
    final rum = _rum;
    if (rum != null) {
      _sdk.dd_rum_destroy(rum);
      _rum = null;
    }
  }

  @override
  Future<String?> getCurrentSessionId() async => null;

  @override
  Future<void> startView(DateTime timestamp, String key, String name,
      Map<String, Object?> attributes) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_start_view(
        rum,
        key.toNativeChar(allocator: arena),
        name.toNativeChar(allocator: arena),
        buildAttrObject(attributes, arena, _sdk),
      );
    });
  }

  @override
  Future<void> stopView(
      DateTime timestamp, String key, Map<String, Object?> attributes) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_stop_view(
        rum,
        key.toNativeChar(allocator: arena),
        buildAttrObject(attributes, arena, _sdk),
      );
    });
  }

  @override
  Future<void> addTiming(DateTime timestamp, String name) async {}

  @override
  Future<void> addViewLoadingTime(bool overwrite) async {}

  @override
  Future<void> startResource(
    DateTime timestamp,
    String key,
    RumHttpMethod httpMethod,
    String url,
    Map<String, Object?> attributes,
  ) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_start_resource(
        rum,
        key.toNativeChar(allocator: arena),
        _methodToC(httpMethod),
        url.toNativeChar(allocator: arena),
        buildAttrObject(attributes, arena, _sdk),
      );
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
  ) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_stop_resource(
        rum,
        key.toNativeChar(allocator: arena),
        statusCode ?? 0,
        size ?? -1,
        _resourceTypeToC(kind),
        buildAttrObject(attributes, arena, _sdk),
      );
    });
  }

  @override
  Future<void> stopResourceWithError(
    DateTime timestamp,
    String key,
    Exception error,
    Map<String, Object?> attributes,
  ) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_stop_resource_with_error(
        rum,
        key.toNativeChar(allocator: arena),
        error.toString().toNativeChar(allocator: arena),
        error.runtimeType.toString().toNativeChar(allocator: arena),
        ffi.nullptr,
        false,
        0,
        buildAttrObject(attributes, arena, _sdk),
      );
    });
  }

  @override
  Future<void> stopResourceWithErrorInfo(
    DateTime timestamp,
    String key,
    String message,
    String type,
    Map<String, Object?> attributes,
  ) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_stop_resource_with_error(
        rum,
        key.toNativeChar(allocator: arena),
        message.toNativeChar(allocator: arena),
        type.toNativeChar(allocator: arena),
        ffi.nullptr,
        false,
        0,
        buildAttrObject(attributes, arena, _sdk),
      );
    });
  }

  @override
  Future<void> addError(
    DateTime timestamp,
    Object error,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes,
  ) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_add_error(
        rum,
        _errorSourceToC(source),
        error.toString().toNativeChar(allocator: arena),
        (errorType ?? error.runtimeType.toString())
            .toNativeChar(allocator: arena),
        stackTrace?.toString().toNativeChar(allocator: arena) ?? ffi.nullptr,
        buildAttrObject(attributes, arena, _sdk),
      );
    });
  }

  @override
  Future<void> addErrorInfo(
    DateTime timestamp,
    String message,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes,
  ) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_add_error(
        rum,
        _errorSourceToC(source),
        message.toNativeChar(allocator: arena),
        errorType.toNativeChar(allocator: arena),
        stackTrace?.toString().toNativeChar(allocator: arena) ?? ffi.nullptr,
        buildAttrObject(attributes, arena, _sdk),
      );
    });
  }

  @override
  Future<void> addAction(DateTime timestamp, RumActionType type, String name,
      Map<String, Object?> attributes) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_add_action(
        rum,
        _actionTypeToC(type),
        name.toNativeChar(allocator: arena),
        buildAttrObject(attributes, arena, _sdk),
      );
    });
  }

  @override
  Future<void> startAction(DateTime timestamp, RumActionType type, String name,
      Map<String, Object?> attributes) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_start_action(
        rum,
        _actionTypeToC(type),
        name.toNativeChar(allocator: arena),
        buildAttrObject(attributes, arena, _sdk),
      );
    });
  }

  @override
  Future<void> stopAction(DateTime timestamp, RumActionType type, String name,
      Map<String, Object?> attributes) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_stop_action(
        rum,
        _actionTypeToC(type),
        name.toNativeChar(allocator: arena),
        buildAttrObject(attributes, arena, _sdk),
      );
    });
  }

  @override
  Future<void> addAttribute(String key, Object value) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_add_attribute(
        rum,
        key.toNativeChar(allocator: arena),
        buildSingleAttr(value, arena, _sdk),
      );
    });
  }

  @override
  Future<void> removeAttribute(String key) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_remove_attribute(rum, key.toNativeChar(allocator: arena));
    });
  }

  @override
  Future<void> setInternalViewAttribute(String key, Object value) async {}

  @override
  Future<void> addViewAttribute(String key, Object value) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_add_view_attribute(
        rum,
        key.toNativeChar(allocator: arena),
        buildSingleAttr(value, arena, _sdk),
      );
    });
  }

  @override
  Future<void> removeViewAttribute(String key) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_remove_view_attribute(
          rum, key.toNativeChar(allocator: arena));
    });
  }

  @override
  Future<void> addViewAttributes(Map<String, Object?> attributes) async {
    for (final entry in attributes.entries) {
      if (entry.value != null) await addViewAttribute(entry.key, entry.value!);
    }
  }

  @override
  Future<void> removeViewAttributes(List<String> keys) async {
    for (final key in keys) {
      await removeViewAttribute(key);
    }
  }

  @override
  Future<void> addFeatureFlagEvaluation(String name, Object value) async {}

  @override
  Future<void> stopSession() async {
    final rum = _rum;
    if (rum != null) _sdk.dd_rum_stop_session(rum);
  }

  @override
  Future<void> startOperation(
    DateTime timestamp,
    String name,
    String? operationKey,
    Map<String, Object?> attributes,
  ) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_start_operation(
        rum,
        name.toNativeChar(allocator: arena),
        operationKey.toNativeChar(allocator: arena),
        buildAttrObject(attributes, arena, _sdk),
      );
    });
  }

  @override
  Future<void> succeedOperation(
    DateTime timestamp,
    String name,
    String? operationKey,
    Map<String, Object?> attributes,
  ) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_succeed_operation(
        rum,
        name.toNativeChar(allocator: arena),
        operationKey.toNativeChar(allocator: arena),
        buildAttrObject(attributes, arena, _sdk),
      );
    });
  }

  @override
  Future<void> failOperation(
    DateTime timestamp,
    String name,
    String? operationKey,
    RumOperationFailureReason failureReason,
    Map<String, Object?> attributes,
  ) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_fail_operation(
        rum,
        name.toNativeChar(allocator: arena),
        _failureReasonToC(failureReason),
        operationKey.toNativeChar(allocator: arena),
        buildAttrObject(attributes, arena, _sdk),
      );
    });
  }

  @override
  Future<void> reportLongTask(DateTime at, int durationMs) async {
    final rum = _rum;
    if (rum == null) return;
    using((arena) {
      _sdk.dd_rum_add_long_task(
        rum,
        _sdk.dd_duration_ms(durationMs),
        ffi.nullptr,
      );
    });
  }

  @override
  Future<void> updatePerformanceMetrics(
      List<double> buildTimes, List<double> rasterTimes) async {}

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int _actionTypeToC(RumActionType type) {
    switch (type) {
      case RumActionType.tap:
        return dd_rum_action_type_t.DD_RUM_ACTION_TYPE_TAP;
      case RumActionType.click:
        return dd_rum_action_type_t.DD_RUM_ACTION_TYPE_CLICK;
      case RumActionType.scroll:
        return dd_rum_action_type_t.DD_RUM_ACTION_TYPE_SCROLL;
      case RumActionType.swipe:
        return dd_rum_action_type_t.DD_RUM_ACTION_TYPE_SWIPE;
      case RumActionType.custom:
        return dd_rum_action_type_t.DD_RUM_ACTION_TYPE_CUSTOM;
    }
  }

  int _methodToC(RumHttpMethod method) {
    switch (method) {
      case RumHttpMethod.get:
        return dd_rum_resource_method_t.DD_RUM_RESOURCE_METHOD_GET;
      case RumHttpMethod.head:
        return dd_rum_resource_method_t.DD_RUM_RESOURCE_METHOD_HEAD;
      case RumHttpMethod.post:
        return dd_rum_resource_method_t.DD_RUM_RESOURCE_METHOD_POST;
      case RumHttpMethod.put:
        return dd_rum_resource_method_t.DD_RUM_RESOURCE_METHOD_PUT;
      case RumHttpMethod.delete:
        return dd_rum_resource_method_t.DD_RUM_RESOURCE_METHOD_DELETE;
      case RumHttpMethod.patch:
        return dd_rum_resource_method_t.DD_RUM_RESOURCE_METHOD_PATCH;
    }
  }

  int _resourceTypeToC(RumResourceType type) {
    switch (type) {
      case RumResourceType.document:
        return dd_rum_resource_type_t.DD_RUM_RESOURCE_TYPE_DOCUMENT;
      case RumResourceType.image:
        return dd_rum_resource_type_t.DD_RUM_RESOURCE_TYPE_IMAGE;
      case RumResourceType.xhr:
        return dd_rum_resource_type_t.DD_RUM_RESOURCE_TYPE_XHR;
      case RumResourceType.beacon:
        return dd_rum_resource_type_t.DD_RUM_RESOURCE_TYPE_BEACON;
      case RumResourceType.css:
        return dd_rum_resource_type_t.DD_RUM_RESOURCE_TYPE_CSS;
      case RumResourceType.fetch:
        return dd_rum_resource_type_t.DD_RUM_RESOURCE_TYPE_FETCH;
      case RumResourceType.font:
        return dd_rum_resource_type_t.DD_RUM_RESOURCE_TYPE_FONT;
      case RumResourceType.js:
        return dd_rum_resource_type_t.DD_RUM_RESOURCE_TYPE_JS;
      case RumResourceType.media:
        return dd_rum_resource_type_t.DD_RUM_RESOURCE_TYPE_MEDIA;
      case RumResourceType.other:
        return dd_rum_resource_type_t.DD_RUM_RESOURCE_TYPE_OTHER;
      case RumResourceType.native:
        return dd_rum_resource_type_t.DD_RUM_RESOURCE_TYPE_NATIVE;
    }
  }

  int _errorSourceToC(RumErrorSource source) {
    switch (source) {
      case RumErrorSource.network:
        return dd_rum_error_source_t.DD_RUM_ERROR_SOURCE_NETWORK;
      case RumErrorSource.source:
        return dd_rum_error_source_t.DD_RUM_ERROR_SOURCE_SOURCE;
      case RumErrorSource.webview:
        return dd_rum_error_source_t.DD_RUM_ERROR_SOURCE_WEBVIEW;
      case RumErrorSource.console:
        return dd_rum_error_source_t.DD_RUM_ERROR_SOURCE_CONSOLE;
      case RumErrorSource.custom:
        return dd_rum_error_source_t.DD_RUM_ERROR_SOURCE_CUSTOM;
    }
  }

  int _failureReasonToC(RumOperationFailureReason reason) {
    switch (reason) {
      case RumOperationFailureReason.error:
        return dd_rum_failure_reason_t.DD_RUM_FAILURE_REASON_ERROR;
      case RumOperationFailureReason.abandoned:
        return dd_rum_failure_reason_t.DD_RUM_FAILURE_REASON_ABANDONED;
      case RumOperationFailureReason.other:
        return dd_rum_failure_reason_t.DD_RUM_FAILURE_REASON_OTHER;
    }
  }
}
