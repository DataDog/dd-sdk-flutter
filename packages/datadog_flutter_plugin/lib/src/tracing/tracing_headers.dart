// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../datadog_internal.dart';

/// The type of tracing header to inject into first party requests.
enum TracingHeaderType {
  /// [Datadog's `x-datadog-*` header](https://docs.datadoghq.com/real_user_monitoring/connect_rum_and_traces/?tab=browserrum#how-are-rum-resources-linked-to-traces).
  datadog,

  /// Open Telemetry B3 [Single header](https://github.com/openzipkin/b3-propagation#single-headers).
  b3,

  /// Open Telemetry B3 [Multiple headers](https://github.com/openzipkin/b3-propagation#multiple-headers).
  b3multi,

  /// W3C [Trace Context header](https://www.w3.org/TR/trace-context/#tracestate-header)
  tracecontext,
}

class DatadogHttpTracingHeaders {
  static const traceId = 'x-datadog-trace-id';
  static const parentId = 'x-datadog-parent-id';

  static const samplingPriority = 'x-datadog-sampling-priority';
  static const origin = 'x-datadog-origin';
}

class OTelHttpTracingHeaders {
  static const multipleTraceId = 'X-B3-TraceId';
  static const multipleSpanId = 'X-B3-SpanId';
  static const multipleParentId = 'X-B3-ParentSpanId';
  static const multipleSampled = 'X-B3-Sampled';

  static const singleB3 = 'b3';
}

class W3CTracingHeaders {
  static const traceparent = 'traceparent';
  static const tracestate = 'tracestate';
}

enum TraceIdRepresentation {
  decimal,
  hex,
  hex16Chars,
  hex32Chars,
}

@immutable
class TracingUUID {
  // Because TraceIDs are unsigned and Dart ints are signed, we store the trace id as a BigInt.
  // Also this will make it easier to switch to 128-bit trace ids at a later date.
  final BigInt value;

  const TracingUUID(this.value);

  static TracingUUID fromString(
      String? uuid, TraceIdRepresentation representation) {
    if (uuid == null) {
      return TracingUUID(BigInt.zero);
    }

    switch (representation) {
      case TraceIdRepresentation.decimal:
        final value = BigInt.tryParse(uuid);
        if (value != null) {
          return TracingUUID(value);
        }
        break;
      case TraceIdRepresentation.hex:
      case TraceIdRepresentation.hex16Chars:
      case TraceIdRepresentation.hex32Chars:
        final value = BigInt.tryParse(uuid, radix: 16);
        if (value != null) {
          return TracingUUID(value);
        }
        break;
    }

    return TracingUUID(BigInt.zero);
  }

  String asString(TraceIdRepresentation representation) {
    switch (representation) {
      case TraceIdRepresentation.decimal:
        return value.toString();
      case TraceIdRepresentation.hex:
        return value.toRadixString(16);
      case TraceIdRepresentation.hex16Chars:
        return value.toRadixString(16).padLeft(16, '0');
      case TraceIdRepresentation.hex32Chars:
        return value.toRadixString(16).padLeft(32, '0');
    }
  }
}

@immutable
class TracingContext {
  final TracingUUID traceId;
  final TracingUUID spanId;
  final TracingUUID? parentSpanId;
  final bool sampled;

  const TracingContext(
      this.traceId, this.spanId, this.parentSpanId, this.sampled);
}

final Random _traceRandom = Random();

TracingUUID _generateTraceId() {
  // Though traceId is an unsigned 64-bit int, for compatibility
  // we assume it needs to be a positive signed 64-bit int, so only
  // use 63-bits.
  final highBits = _traceRandom.nextInt(1 << 31);
  final lowBits = BigInt.from(_traceRandom.nextInt(pow(2, 32).toInt()));

  var traceId = BigInt.from(highBits) << 32;
  traceId += lowBits;

  return TracingUUID(traceId);
}

/// Generate a tracing context
TracingContext generateTracingContext(bool sampled) {
  return TracingContext(_generateTraceId(), _generateTraceId(), null, sampled);
}

Map<String, Object?> generateDatadogAttributes(
    TracingContext? context, double samplingRate) {
  var attributes = <String, Object?>{};

  if (context != null) {
    attributes[DatadogRumPlatformAttributeKey.rulePsr] = samplingRate / 100.0;
    if (context.sampled) {
      attributes[DatadogRumPlatformAttributeKey.traceID] =
          context.traceId.asString(TraceIdRepresentation.decimal);
      attributes[DatadogRumPlatformAttributeKey.spanID] =
          context.spanId.asString(TraceIdRepresentation.decimal);
    }
  }

  return attributes;
}

Map<String, String> getTracingHeaders(
  TracingContext context,
  TracingHeaderType headersType,
) {
  var headers = <String, String>{};

  final sampledString = context.sampled ? '1' : '0';

  switch (headersType) {
    case TracingHeaderType.datadog:
      if (context.sampled) {
        headers[DatadogHttpTracingHeaders.traceId] =
            context.traceId.asString(TraceIdRepresentation.decimal);
        headers[DatadogHttpTracingHeaders.parentId] =
            context.spanId.asString(TraceIdRepresentation.decimal);
      }
      headers[DatadogHttpTracingHeaders.origin] = 'rum';
      headers[DatadogHttpTracingHeaders.samplingPriority] = sampledString;
      break;
    case TracingHeaderType.b3:
      if (context.sampled) {
        final headerValue = [
          context.traceId.asString(TraceIdRepresentation.hex32Chars),
          context.spanId.asString(TraceIdRepresentation.hex16Chars),
          sampledString,
          context.parentSpanId?.asString(TraceIdRepresentation.hex16Chars),
        ].whereType<String>().join('-');
        headers[OTelHttpTracingHeaders.singleB3] = headerValue;
      } else {
        headers[OTelHttpTracingHeaders.singleB3] = sampledString;
      }
      break;
    case TracingHeaderType.b3multi:
      headers[OTelHttpTracingHeaders.multipleSampled] = sampledString;

      if (context.sampled) {
        headers[OTelHttpTracingHeaders.multipleTraceId] =
            context.traceId.asString(TraceIdRepresentation.hex32Chars);
        headers[OTelHttpTracingHeaders.multipleSpanId] =
            context.spanId.asString(TraceIdRepresentation.hex16Chars);
        if (context.parentSpanId != null) {
          headers[OTelHttpTracingHeaders.multipleParentId] =
              context.parentSpanId!.asString(TraceIdRepresentation.hex16Chars);
        }
      }
      break;
    case TracingHeaderType.tracecontext:
      final spanString =
          context.spanId.asString(TraceIdRepresentation.hex16Chars);
      final parentHeaderValue = [
        '00', // Version Code
        context.traceId.asString(TraceIdRepresentation.hex32Chars),
        spanString,
        context.sampled ? '01' : '00'
      ].join('-');
      final stateHeaderValue = [
        's:$sampledString',
        'o:rum',
        'p:$spanString',
      ].join(';');
      headers[W3CTracingHeaders.traceparent] = parentHeaderValue;
      headers[W3CTracingHeaders.tracestate] = 'dd=$stateHeaderValue';
      break;
  }

  return headers;
}
