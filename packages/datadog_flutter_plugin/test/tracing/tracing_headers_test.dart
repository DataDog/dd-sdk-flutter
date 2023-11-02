// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/src/tracing/tracing_headers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generateTracingContext generates 64-bit values', () {
    final context = generateTracingContext(true);

    expect(context.traceId.value.bitLength, lessThanOrEqualTo(63));
    expect(context.spanId.value.bitLength, lessThanOrEqualTo(63));
    expect(context.sampled, true);
  });

  test('Datadog attributes generated correctly', () {
    final context = generateTracingContext(true);

    final attributes = generateDatadogAttributes(context, 30.0);

    expect(attributes['_dd.trace_id'],
        context.traceId.asString(TraceIdRepresentation.decimal));
    expect(attributes['_dd.span_id'],
        context.spanId.asString(TraceIdRepresentation.decimal));
    expect(attributes['_dd.rule_psr'], 0.3);
  });

  test('Sampled context does not generate datadog attributes', () {
    final context = generateTracingContext(false);

    final attributes = generateDatadogAttributes(context, 30.0);

    expect(attributes['_dd.trace_id'], isNull);
    expect(attributes['_dd.span_id'], isNull);
    expect(attributes['_dd.rule_psr'], 0.3);
  });

  test('Datadog tracing headers are generated correctly { sampled }', () {
    final context = generateTracingContext(true);

    final headers = getTracingHeaders(context, TracingHeaderType.datadog);

    expect(headers['x-datadog-trace-id'],
        context.traceId.asString(TraceIdRepresentation.decimal));
    expect(headers['x-datadog-parent-id'],
        context.spanId.asString(TraceIdRepresentation.decimal));
    expect(headers['x-datadog-sampling-priority'], '1');
    expect(headers['x-datadog-origin'], 'rum');
  });

  test('Datadog tracing headers are generated correctly { unsampled }', () {
    final context = generateTracingContext(false);

    final headers = getTracingHeaders(context, TracingHeaderType.datadog);

    expect(headers['x-datadog-trace-id'], isNull);
    expect(headers['x-datadog-parent-id'], isNull);
    expect(headers['x-datadog-sampling-priority'], '0');
    expect(headers['x-datadog-origin'], 'rum');
  });

  test('b3 tracing headers are generated correctly { sampled }', () {
    final context = generateTracingContext(true);

    final headers = getTracingHeaders(context, TracingHeaderType.b3);

    final traceString =
        context.traceId.asString(TraceIdRepresentation.hex32Chars);
    final spanString =
        context.spanId.asString(TraceIdRepresentation.hex16Chars);
    final expectedHeader = '$traceString-$spanString-1';

    expect(headers['b3'], expectedHeader);
  });

  test('b3 tracing headers are generated correctly { unsampled }', () {
    final context = generateTracingContext(false);

    final headers = getTracingHeaders(context, TracingHeaderType.b3);

    expect(headers['b3'], '0');
  });

  test('b3multi tracing headers are generated correctly { sampled }', () {
    final context = generateTracingContext(true);

    final headers = getTracingHeaders(context, TracingHeaderType.b3multi);

    final traceString =
        context.traceId.asString(TraceIdRepresentation.hex32Chars);
    final spanString =
        context.spanId.asString(TraceIdRepresentation.hex16Chars);

    expect(headers['X-B3-TraceId'], traceString);
    expect(headers['X-B3-SpanId'], spanString);
    expect(headers['X-B3-ParentSpanId'], isNull);
    expect(headers['X-B3-Sampled'], '1');
  });

  test('b3multi tracing headers are generated correctly { unsampled }', () {
    final context = generateTracingContext(false);

    final headers = getTracingHeaders(context, TracingHeaderType.b3multi);

    expect(headers['X-B3-TraceId'], isNull);
    expect(headers['X-B3-SpanId'], isNull);
    expect(headers['X-B3-ParentSpanId'], isNull);
    expect(headers['X-B3-Sampled'], '0');
  });

  test('tracecontext tracing headers are generated correctly { sampled }', () {
    final context = generateTracingContext(true);

    final headers = getTracingHeaders(context, TracingHeaderType.tracecontext);

    final traceString =
        context.traceId.asString(TraceIdRepresentation.hex32Chars);
    final spanString =
        context.spanId.asString(TraceIdRepresentation.hex16Chars);
    final expectedParentHeader = '00-$traceString-$spanString-01';
    const expectedStateHeader = 's:1;o:rum';

    expect(headers['traceparent'], expectedParentHeader);
    expect(headers['tracestate'], expectedStateHeader);
  });

  test('traceparent tracing headers are generated correctly { unsampled }', () {
    final context = generateTracingContext(false);

    final headers = getTracingHeaders(context, TracingHeaderType.tracecontext);

    final traceString =
        context.traceId.asString(TraceIdRepresentation.hex32Chars);
    final spanString =
        context.spanId.asString(TraceIdRepresentation.hex16Chars);
    final expectedParentHeader = '00-$traceString-$spanString-00';
    const expectedStateHeader = 's:0;o:rum';

    expect(headers['traceparent'], expectedParentHeader);
    expect(headers['tracestate'], expectedStateHeader);
  });
}
