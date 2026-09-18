// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../datadog_flutter_plugin.dart';
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
  static const tags = 'x-datadog-tags';
  static const samplingPriority = 'x-datadog-sampling-priority';
  static const origin = 'x-datadog-origin';

  static const traceIdTag = '_dd.p.tid';
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
  static const baggage = 'baggage';
}

/// Controls how we print a TracingId
enum TracingIdRepresentation {
  /// Decimal string representation of the tracing id
  decimal,

  /// The low 64-bits of rhe tracing id as a decimal
  lowDecimal,

  /// Hexadecimal string representation of the full tracing id
  hex,

  /// Hexadecimal string representation of the low 64-bits of the tracing id
  hex16Chars,

  /// Hexadecimal string representation of the high 64-bits of the tracing id
  highHex16Chars,

  /// Hexadecimal string representation of the full 128-bits of the tracing id
  hex32Chars,
}

/// Type alias for [TracingIdRepresentation] to ensure backwards
/// compatibility with other packages
@Deprecated('Use [TracingIdRepresentation] instead.')
typedef TraceIdRepresentation = TracingIdRepresentation;

// A value to mask the high 64-bits from a 128-bit trace id.
@visibleForTesting
final lowTraceMask = (BigInt.from(0xffffffff) << 32) + BigInt.from(0xffffffff);

final _maxRandInt = kIsWeb ? 1 << 31 : 1 << 32;

/// [TracingId] is used as both a unsigned 64-bit "Span Id" and unsigned 128-bit "Trace Id"
@immutable
class TracingId {
  // Because Span Ids are unsigned and Dart ints are signed, we have to store the id as a BigInt
  // to be able to store all 64-bits properly.
  final BigInt value;

  const TracingId(this.value);

  TracingId.zero() : this(BigInt.zero);

  static TracingId fromString(
    String? id,
    TracingIdRepresentation representation,
  ) {
    if (id == null) {
      return TracingId(BigInt.zero);
    }

    switch (representation) {
      case TracingIdRepresentation.lowDecimal:
      case TracingIdRepresentation.decimal:
        final value = BigInt.tryParse(id);
        if (value != null) {
          return TracingId(value);
        }
        break;
      case TracingIdRepresentation.hex:
      case TracingIdRepresentation.hex16Chars:
      case TracingIdRepresentation.hex32Chars:
        final value = BigInt.tryParse(id, radix: 16);
        if (value != null) {
          return TracingId(value);
        }
        break;
      case TracingIdRepresentation.highHex16Chars:
        // Take only the last 16 chars
        if (id.length > 16) {
          id = id.substring(id.length - 16);
        }
        final value = BigInt.tryParse(id, radix: 16);
        if (value != null) {
          return TracingId(value);
        }
        break;
    }

    return TracingId(BigInt.zero);
  }

  String asString(TracingIdRepresentation representation) {
    switch (representation) {
      case TracingIdRepresentation.decimal:
        return value.toString();
      case TracingIdRepresentation.lowDecimal:
        return (value & lowTraceMask).toString();
      case TracingIdRepresentation.hex:
        return value.toRadixString(16);
      case TracingIdRepresentation.hex16Chars:
        return (value & lowTraceMask).toRadixString(16).padLeft(16, '0');
      case TracingIdRepresentation.highHex16Chars:
        return (value >> 64).toRadixString(16).padLeft(16, '0');
      case TracingIdRepresentation.hex32Chars:
        return value.toRadixString(16).padLeft(32, '0');
    }
  }

  TracingId.traceId() : value = _generateTraceId();

  TracingId.spanId() : value = _generateSpanId();

  /// Generate a 128-bit Trace Id.
  ///
  /// The trace is generated within the range:
  /// <32-bit unix seconds> <32-bits of zero> <64-bits random>
  static BigInt _generateTraceId() {
    final time = (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    final highBits = BigInt.from(_traceRandom.nextInt(_maxRandInt));
    final lowBits = BigInt.from(_traceRandom.nextInt(_maxRandInt));

    var traceId = BigInt.from(time) << 96;
    traceId += (highBits << 32);
    traceId += lowBits;

    return traceId;
  }

  /// Generate a 64-bit Span Id
  static BigInt _generateSpanId() {
    // Though Span Ids is an unsigned 64-bit int, for compatibility
    // we assume it needs to be a positive signed 64-bit int, so only
    // use 63-bits.
    final highBits = _traceRandom.nextInt(1 << 31);
    final lowBits = BigInt.from(_traceRandom.nextInt(_maxRandInt));

    var spanId = BigInt.from(highBits) << 32;
    spanId += lowBits;

    return spanId;
  }
}

@immutable
class TracingContext {
  final TracingId traceId;
  final TracingId spanId;
  final TracingId? parentSpanId;
  final String? rumSessionId;
  final String? userId;
  final String? accountId;
  final bool sampled;

  const TracingContext(
    this.traceId,
    this.spanId,
    this.parentSpanId,
    this.rumSessionId,
    this.userId,
    this.accountId,
    this.sampled,
  );
}

final Random _traceRandom = Random();

/// Generate a tracing context
TracingContext generateTracingContext(DatadogSdk sdk, DatadogRum rum) {
  final traceId = TracingId.traceId();
  final spanId = TracingId.spanId();
  final context = sdk.platform.getContext();
  bool sampled = rum.shouldSampleTrace(context?.sessionId, traceId);
  return TracingContext(
    traceId,
    spanId,
    null,
    context?.sessionId,
    context?.userId,
    context?.accountId,
    sampled,
  );
}

Map<String, Object?> generateDatadogAttributes(
  TracingContext? context,
  double samplingRate,
) {
  var attributes = <String, Object?>{};

  if (context != null) {
    attributes[DatadogRumPlatformAttributeKey.rulePsr] = samplingRate / 100.0;
    if (context.sampled) {
      attributes[DatadogRumPlatformAttributeKey.traceID] =
          context.traceId.asString(TracingIdRepresentation.hex32Chars);
      attributes[DatadogRumPlatformAttributeKey.spanID] =
          context.spanId.asString(TracingIdRepresentation.decimal);
    }
  }

  return attributes;
}

void injectTracingHeaders(
  TracingContext context,
  TracingHeaderType headersType,
  Map<String, dynamic> headers, {
  TraceContextInjection contextInjection = TraceContextInjection.sampled,
}) {
  const String baggageHeaderName = 'baggage';

  final sampledString = context.sampled ? '1' : '0';
  bool shouldInjectHeaders =
      context.sampled || contextInjection == TraceContextInjection.all;

  void addHeader(String key, String value) {
    if (!headers.containsKey(key)) {
      headers[key] = value;
    }
  }

  switch (headersType) {
    case TracingHeaderType.datadog:
      if (shouldInjectHeaders) {
        addHeader(
          DatadogHttpTracingHeaders.traceId,
          context.traceId.asString(TracingIdRepresentation.lowDecimal),
        );
        addHeader(
          DatadogHttpTracingHeaders.tags,
          '${DatadogHttpTracingHeaders.traceIdTag}=${context.traceId.asString(TracingIdRepresentation.highHex16Chars)}',
        );
        addHeader(
          DatadogHttpTracingHeaders.parentId,
          context.spanId.asString(TracingIdRepresentation.decimal),
        );
        addHeader(DatadogHttpTracingHeaders.origin, 'rum');
        addHeader(DatadogHttpTracingHeaders.samplingPriority, sampledString);

        headers[baggageHeaderName] = mergeW3CBaggageHeader(
          context,
          headers[baggageHeaderName],
        );
      }
      break;
    case TracingHeaderType.b3:
      if (context.sampled) {
        final headerValue = [
          context.traceId.asString(TracingIdRepresentation.hex32Chars),
          context.spanId.asString(TracingIdRepresentation.hex16Chars),
          sampledString,
          context.parentSpanId?.asString(TracingIdRepresentation.hex16Chars),
        ].whereType<String>().join('-');
        addHeader(OTelHttpTracingHeaders.singleB3, headerValue);
      } else if (contextInjection == TraceContextInjection.all) {
        addHeader(OTelHttpTracingHeaders.singleB3, sampledString);
      }
      break;
    case TracingHeaderType.b3multi:
      if (shouldInjectHeaders) {
        addHeader(OTelHttpTracingHeaders.multipleSampled, sampledString);
      }

      if (context.sampled) {
        addHeader(
          OTelHttpTracingHeaders.multipleTraceId,
          context.traceId.asString(TracingIdRepresentation.hex32Chars),
        );
        addHeader(
          OTelHttpTracingHeaders.multipleSpanId,
          context.spanId.asString(TracingIdRepresentation.hex16Chars),
        );
        if (context.parentSpanId != null) {
          addHeader(
            OTelHttpTracingHeaders.multipleParentId,
            context.parentSpanId!.asString(TracingIdRepresentation.hex16Chars),
          );
        }
      }
      break;
    case TracingHeaderType.tracecontext:
      if (shouldInjectHeaders) {
        final spanString = context.spanId.asString(
          TracingIdRepresentation.hex16Chars,
        );
        final parentHeaderValue = [
          '00', // Version Code
          context.traceId.asString(TracingIdRepresentation.hex32Chars),
          spanString,
          context.sampled ? '01' : '00',
        ].join('-');
        final stateHeaderValue = [
          's:$sampledString',
          'o:rum',
          'p:$spanString',
        ].join(';');
        addHeader(W3CTracingHeaders.traceparent, parentHeaderValue);
        addHeader(W3CTracingHeaders.tracestate, 'dd=$stateHeaderValue');

        headers[baggageHeaderName] = mergeW3CBaggageHeader(
          context,
          headers[baggageHeaderName],
        );
      }
      break;
  }
}
