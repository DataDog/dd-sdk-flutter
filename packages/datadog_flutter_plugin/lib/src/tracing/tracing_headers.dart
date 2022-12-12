// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'dart:math';

import 'package:flutter/material.dart';

/// The type of tracing header to inject into first party requests.
enum TracingHeaderType {
  /// [Datadog's `x-datadog-*` header](https://docs.datadoghq.com/real_user_monitoring/connect_rum_and_traces/?tab=browserrum#how-are-rum-resources-linked-to-traces).
  dd,

  /// Open Telemetry B3 [Single header](https://github.com/openzipkin/b3-propagation#single-headers).
  b3s,

  /// Open Telemetry B3 [Multiple headers](https://github.com/openzipkin/b3-propagation#multiple-headers).
  b3m,
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

  static TracingUUID? fromString(
      String? uuid, TraceIdRepresentation representation) {
    if (uuid == null) {
      return null;
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

    return null;
  }

  String asString(TraceIdRepresentation representation) {
    switch (representation) {
      case TraceIdRepresentation.decimal:
        return value.toString();
      case TraceIdRepresentation.hex:
        return value.toRadixString(16);
      case TraceIdRepresentation.hex16Chars:
        return value.toRadixString(16).padLeft(16);
      case TraceIdRepresentation.hex32Chars:
        return value.toRadixString(16).padLeft(32);
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
  // Though traceid is an unsigned 64-bit int, for compatibility
  // we assume it needs to be a positive signed 64-bit int, so only
  // use 63-bits.
  final highBits = _traceRandom.nextInt(1 << 31);
  final lowBits = BigInt.from(_traceRandom.nextInt(1 << 32));

  var traceId = BigInt.from(highBits) << 32;
  traceId += lowBits;

  return TracingUUID(traceId);
}

/// Read the tracing context from the requests headers
TracingContext? readTracingContext(Map<String, String> headers) {
  final multipleTraceIdStr = headers[OTelHttpTracingHeaders.multipleTraceId];
  final multipleSpanIdStr = headers[OTelHttpTracingHeaders.multipleSpanId];
  final singleB3Str = headers[OTelHttpTracingHeaders.singleB3];
  if (multipleTraceIdStr != null && multipleSpanIdStr != null) {
    final traceId =
        TracingUUID.fromString(multipleTraceIdStr, TraceIdRepresentation.hex);
    final spanId =
        TracingUUID.fromString(multipleTraceIdStr, TraceIdRepresentation.hex);
    if (traceId != null && spanId != null) {
      final parentSpanId = TracingUUID.fromString(
        headers[OTelHttpTracingHeaders.multipleParentId],
        TraceIdRepresentation.hex,
      );

      final sampled = headers[OTelHttpTracingHeaders.multipleSampled] == '1';

      return TracingContext(traceId, spanId, parentSpanId, sampled);
    }
  } else if (singleB3Str != null) {
    final components = singleB3Str.split('-');
    if (components.length > 1) {
      final traceId =
          TracingUUID.fromString(components[0], TraceIdRepresentation.hex);
      final spanId =
          TracingUUID.fromString(components[1], TraceIdRepresentation.hex);
      if (traceId != null && spanId != null) {
        final sampled = components[2] == '1';
        final parentSpanId = TracingUUID.fromString(
            components.length > 3 ? components[3] : null,
            TraceIdRepresentation.hex);

        return TracingContext(traceId, spanId, parentSpanId, sampled);
      }
    }
  }

  return null;
}

/// Generate a tracing context
TracingContext generateTracingContext(bool sampled) {
  return TracingContext(_generateTraceId(), _generateTraceId(), null, sampled);
}

void injectHeaders(TracingContext context, TracingHeaderType headersType,
    Map<String, String> headers) {
  final sampledString = context.sampled ? '1' : '0';
  switch (headersType) {
    case TracingHeaderType.dd:
      if (context.sampled) {
        headers[DatadogHttpTracingHeaders.origin] = 'rum';
        headers[DatadogHttpTracingHeaders.traceId] =
            context.traceId.asString(TraceIdRepresentation.decimal);
        headers[DatadogHttpTracingHeaders.parentId] =
            context.spanId.asString(TraceIdRepresentation.decimal);
      }
      headers[DatadogHttpTracingHeaders.samplingPriority] = sampledString;
      break;
    case TracingHeaderType.b3s:
      if (context.sampled) {
        final headerValue = [
          context.spanId.asString(TraceIdRepresentation.hex32Chars),
          context.traceId.asString(TraceIdRepresentation.hex16Chars),
          sampledString,
          context.parentSpanId?.asString(TraceIdRepresentation.hex16Chars),
        ].whereType<String>().join('-');
        headers[OTelHttpTracingHeaders.singleB3] = headerValue;
      } else {
        headers[OTelHttpTracingHeaders.singleB3] = sampledString;
      }
      break;
    case TracingHeaderType.b3m:
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
  }
}
