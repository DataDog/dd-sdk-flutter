// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// ignore_for_file: non_constant_identifier_names

import 'dart:js_interop';

import '../../web_helpers.dart';
import '../rum.dart';

extension type RumWebCount._(JSObject _) implements JSObject {
  external int number;

  external factory RumWebCount({required int number});
}

extension type RumWebRawEvent._(JSObject _) implements JSObject {
  external JSObject context;

  external factory RumWebRawEvent({JSObject context});
}

extension type RumWebEventDomainContext._(JSObject _) implements JSObject {
  external RumWebEventDomainContext();
}

extension type RumWebRawEventViewData._(JSObject _) implements JSObject {
  @JS('in_foreground')
  external bool inForeground;
}

// MARK: Error Events and Context

extension type RumWebRawErrorResource._(JSObject _) implements JSObject {
  external String method;
  @JS('status_code')
  external int statusCode;
  external String url;

  external RumWebRawErrorResource({
    required String method,
    required int status_code,
    required String url,
  });
}

extension type RumWebRawErrorData.__(JSObject __) implements JSObject {
  external String id;
  external String? type;
  external String? stack;
  @JS('handling_stack')
  external String? handlingStack;
  @JS('component_stack')
  external String? componentStack;
  external String? fingerprint;
  external String? source;
  external String message;
  external String? handling;
  @JS('source_type')
  external String sourceType;
  external RumWebRawErrorResource? resource;

  factory RumWebRawErrorData({
    required String id,
    String? type,
    String? stack,
    String? handling_stack,
    String? component_stack,
    String? fingerprint,
    String? source,
    required String message,
    String? handling,
    String source_type = 'browser',
    RumWebRawErrorResource? resource,
  }) => RumWebRawErrorData._(
    id: id,
    message: message,
    type: type,
    stack: stack,
    handling_stack: handling_stack,
    component_stack: component_stack,
    fingerprint: fingerprint,
    source: source,
    handling: handling,
    source_type: source_type,
    resource: resource,
  );

  external factory RumWebRawErrorData._({
    required String id,
    String? type,
    String? stack,
    String? handling_stack,
    String? component_stack,
    String? fingerprint,
    String? source,
    required String message,
    String? handling,
    String source_type,
    RumWebRawErrorResource? resource,
  });
}

extension type RumWebRawErrorEvent.__(RumWebRawEvent __)
    implements RumWebRawEvent {
  external JSNumber date;
  external String type;
  external RumWebRawErrorData error;

  factory RumWebRawErrorEvent({
    required JSNumber date,
    required JSObject context,
    required RumWebRawErrorData error,
  }) => RumWebRawErrorEvent._(
    type: 'error',
    date: date,
    context: context,
    error: error,
  );

  external factory RumWebRawErrorEvent._({
    JSObject context,
    required JSNumber date,
    required String type,
    required RumWebRawErrorData error,
  });
}

String errorSourceToJs(RumErrorSource source) {
  return switch (source) {
    RumErrorSource.source => 'source',
    RumErrorSource.network => 'network',
    RumErrorSource.webview => 'webview',
    RumErrorSource.console => 'console',
    RumErrorSource.custom => 'custom',
  };
}

extension type RumWebErrorEventDomainContext._(RumWebEventDomainContext _)
    implements RumWebEventDomainContext {
  external JSObject error;
  external String? handlingStack;

  external factory RumWebErrorEventDomainContext({
    JSObject error,
    String? handlingStack,
  });
}

// MARK: Action Events and Context

extension type RumWebActionTarget._(JSObject _) implements JSObject {
  external String name;

  external RumWebActionTarget({required String name});
}

extension type RumWebRawActionData._(JSObject _) implements JSObject {
  external String id;
  external String type;
  @JS('loading_time')
  external JSNumber? loadingTime;
  external RumWebCount? error;
  @JS('long_task')
  external RumWebCount? longTask;
  external RumWebCount? resource;
  external RumWebActionTarget target;

  external factory RumWebRawActionData({
    required String id,
    required String type,
    JSNumber? loading_time,
    RumWebCount? error,
    RumWebCount? long_task,
    RumWebCount? resource,
    required RumWebActionTarget target,
  });
}

extension type RumWebRawActionEvent.__(RumWebRawEvent __)
    implements RumWebRawEvent {
  external JSNumber date;
  external String type;
  external RumWebRawActionData action;

  factory RumWebRawActionEvent({
    required JSNumber date,
    required JSObject context,
    required RumWebRawActionData action,
    RumWebRawEventViewData? view,
  }) => RumWebRawActionEvent._(
    date: date,
    context: context,
    type: 'action',
    action: action,
  );

  external factory RumWebRawActionEvent._({
    required JSNumber date,
    required JSObject context,
    required String type,
    required RumWebRawActionData action,
  });
}

extension type RumWebActionEventDomainContext._(RumWebEventDomainContext _)
    implements RumWebEventDomainContext {
  external String? handlingStack;

  external factory RumWebActionEventDomainContext({String? handlingStack});
}

String actionTypeToJs(RumActionType source) {
  return switch (source) {
    RumActionType.click => 'click',
    RumActionType.tap => 'tap',
    RumActionType.scroll => 'scroll',
    RumActionType.swipe => 'swipe',
    RumActionType.custom => 'custom',
  };
}

// MARK: Resource Events and Context

extension type RumWebRawResourceData._(JSObject _) implements JSObject {
  external String id;
  external String type;
  external JSNumber? duration;
  external String url;
  external String? method;
  @JS('status_code')
  external JSNumber? statusCode;
  external JSNumber? size;
  @JS('encoded_body_size')
  external JSNumber? encodedBodySize;
  @JS('decoded_body_size')
  external JSNumber? decodedBodySize;
  @JS('transfer_size')
  external JSNumber? transferSize;
  @JS('render_blocking_status')
  external String? renderBlockingStatus;
  external String? protocol;

  external factory RumWebRawResourceData({
    required String id,
    required String type,
    JSNumber? duration,
    required String url,
    String? method,
    JSNumber? status_code,
    JSNumber? size,
    JSNumber? encoded_body_size,
    JSNumber? decoded_body_size,
    JSNumber? transfer_size,
    String? render_blocking_status,
    String? protocol,
  });
}

extension type RumWebRawResourceDdData._(JSObject _) implements JSObject {
  @JS('trace_id')
  external String? traceId;
  @JS('span_id')
  external String? spanId;
  @JS('rule_psr')
  external JSNumber? rulePsr;
  external bool discarded;

  external factory RumWebRawResourceDdData({
    String? trace_id,
    String? span_id,
    JSNumber? rule_psr,
    required bool discarded,
  });
}

@anonymous
extension type RumWebRawError._(JSObject _) {
  external String name;
  external String message;
  external String? stack;

  external factory RumWebRawError({
    required String name,
    required String message,
    String? stack,
  });
}

extension type RumWebResourceEventDomainContext._(RumWebEventDomainContext _)
    implements RumWebEventDomainContext {
  external JSObject? performanceEntry;
  external RumWebRawError? error;

  external factory RumWebResourceEventDomainContext({
    required JSObject? performanceEntry,
    RumWebRawError? error,
  });
}

extension type RumWebRawResourceEvent.__(RumWebRawEvent __)
    implements RumWebRawEvent {
  external JSNumber date;
  external String type;
  external RumWebRawResourceData resource;
  @JS('_dd')
  external RumWebRawResourceDdData dd;

  factory RumWebRawResourceEvent({
    required JSNumber date,
    required RumWebRawResourceData resource,
    required RumWebRawResourceDdData dd,
    Map<String, Object?>? context,
  }) {
    final value = RumWebRawResourceEvent._(
      date: date,
      type: 'resource',
      resource: resource,
      context: valueToJs(context ?? {}, 'context') as JSObject,
    )..dd = dd;
    return value;
  }

  external factory RumWebRawResourceEvent._({
    required JSNumber date,
    required String type,
    required RumWebRawResourceData resource,
    required JSObject context,
  });
}
