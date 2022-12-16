// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../datadog_internal.dart';

/// The type of tracing header to inject into first party requests.
enum TracingHeaderType {
  /// [Datadog's `x-datadog-*` header](https://docs.datadoghq.com/real_user_monitoring/connect_rum_and_traces/?tab=browserrum#how-are-rum-resources-linked-to-traces).
  dd,

  /// Open Telemetry B3 [Single header](https://github.com/openzipkin/b3-propagation#single-headers).
  b3,

  /// Open Telemetry B3 [Multiple headers](https://github.com/openzipkin/b3-propagation#multiple-headers).
  b3m,

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
}

enum TraceIdRepresentation {
  decimal,
  decimal63bit,
  hex,
  hex16Chars,
  hex32Chars,
}

@immutable
class TracingUUID {
  // 63-bit mask for truncating OTel trace Ids.
  static final BigInt _ddTraceMask = BigInt.from(0x7fffffffffffffff);

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
      case TraceIdRepresentation.decimal63bit:
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
      case TraceIdRepresentation.decimal63bit:
        final truncatedValue = value & _ddTraceMask;
        return truncatedValue.toString();
      case TraceIdRepresentation.hex:
        return value.toRadixString(16);
      case TraceIdRepresentation.hex16Chars:
        return value.toRadixString(16).toUpperCase().padLeft(16, '0');
      case TraceIdRepresentation.hex32Chars:
        return value.toRadixString(16).toUpperCase().padLeft(32, '0');
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
  final lowBits = BigInt.from(_traceRandom.nextInt(1 << 32));

  var traceId = BigInt.from(highBits) << 32;
  traceId += lowBits;

  return TracingUUID(traceId);
}

/// Read the tracing context from the requests headers -- note that
/// headers should be lowercased
TracingContext? readTracingContext(Map<String, String> headers) {
  TracingUUID? traceId;
  TracingUUID? spanId;
  TracingUUID? parentSpanId;
  bool? sampled;

  final b3mSampledStr =
      headers[OTelHttpTracingHeaders.multipleSampled.toLowerCase()];
  final singleB3Str = headers[OTelHttpTracingHeaders.singleB3.toLowerCase()];
  final tracecontext = headers[W3CTracingHeaders.traceparent];

  if (b3mSampledStr != null) {
    sampled = b3mSampledStr == '1';

    traceId = TracingUUID.fromString(
        headers[OTelHttpTracingHeaders.multipleTraceId.toLowerCase()],
        TraceIdRepresentation.hex);
    spanId = TracingUUID.fromString(
        headers[OTelHttpTracingHeaders.multipleSpanId.toLowerCase()],
        TraceIdRepresentation.hex);
    parentSpanId = TracingUUID.fromString(
        headers[OTelHttpTracingHeaders.multipleParentId.toLowerCase()],
        TraceIdRepresentation.hex);
  } else if (singleB3Str != null) {
    // Assumption - malformed b3 header is not sampled.
    sampled = false;

    final components = singleB3Str.split('-');

    if (components.length > 2) {
      traceId =
          TracingUUID.fromString(components[0], TraceIdRepresentation.hex);
      spanId = TracingUUID.fromString(components[1], TraceIdRepresentation.hex);
      sampled = components[2] == '1';
      parentSpanId = TracingUUID.fromString(
          components.length > 3 ? components[3] : null,
          TraceIdRepresentation.hex);

      return TracingContext(traceId, spanId, parentSpanId, sampled);
    }
  } else if (tracecontext != null) {
    // Assumption - malformed b3 header is not sampled.
    sampled = false;

    final components = tracecontext.split('-');
    if (components.length > 3 && components[0] == '00') {
      traceId =
          TracingUUID.fromString(components[1], TraceIdRepresentation.hex);
      spanId = TracingUUID.fromString(components[2], TraceIdRepresentation.hex);
      sampled = components[3] == '01';
    }
  }

  if (sampled != null) {
    traceId ??= TracingUUID(BigInt.zero);
    spanId ??= TracingUUID(BigInt.zero);
    return TracingContext(traceId, spanId, parentSpanId, sampled);
  }

  return null;
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
          context.traceId.asString(TraceIdRepresentation.decimal63bit);
      attributes[DatadogRumPlatformAttributeKey.spanID] =
          context.spanId.asString(TraceIdRepresentation.decimal63bit);
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
    case TracingHeaderType.dd:
      if (context.sampled) {
        headers[DatadogHttpTracingHeaders.traceId] =
            context.traceId.asString(TraceIdRepresentation.decimal63bit);
        headers[DatadogHttpTracingHeaders.parentId] =
            context.spanId.asString(TraceIdRepresentation.decimal63bit);
      }
      headers[DatadogHttpTracingHeaders.origin] = 'rum';
      headers[DatadogHttpTracingHeaders.samplingPriority] = sampledString;
      break;
    case TracingHeaderType.b3:
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
    case TracingHeaderType.tracecontext:
      final headerValue = [
        '00', // Version Code
        context.spanId.asString(TraceIdRepresentation.hex32Chars),
        context.traceId.asString(TraceIdRepresentation.hex16Chars),
        context.sampled ? '01' : '00'
      ].join('-');
      headers[W3CTracingHeaders.traceparent] = headerValue;
      break;
  }

  return headers;
}
