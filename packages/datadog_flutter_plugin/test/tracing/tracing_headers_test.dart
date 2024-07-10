// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/src/tracing/tracing_headers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TracingIdRepresentation generates proper values', () {
    // Create a value in 128-bit hex that has leading zeros on both
    // the low and high 64-bits, and ensure we get the proper values
    const low = 0x01445feed89934bb;
    const high = 0x01222f00d89934ba;

    var combined = BigInt.from(high);
    combined = (combined << 64) + BigInt.from(low);

    final tracingId = TracingId(combined);

    expect(tracingId.asString(TracingIdRepresentation.hex),
        '1222f00d89934ba01445feed89934bb');
    expect(tracingId.asString(TracingIdRepresentation.hex32Chars),
        '01222f00d89934ba01445feed89934bb');
    expect(tracingId.asString(TracingIdRepresentation.hex16Chars),
        '01445feed89934bb');
    expect(tracingId.asString(TracingIdRepresentation.highHex16Chars),
        '01222f00d89934ba');
    expect(tracingId.asString(TracingIdRepresentation.decimal),
        '1506719429260448406838152867989763259');
    expect(tracingId.asString(TracingIdRepresentation.lowDecimal),
        '91303371895026875');
  });

  test('traceId generates proper values', () {
    final nowSeconds = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final traceId = TracingId.traceId();

    final traceIdString = traceId.asString(TracingIdRepresentation.hex);
    int traceSeconds = int.parse(traceIdString.substring(0, 8), radix: 16);
    expect(traceSeconds, closeTo(nowSeconds, 1));
    expect('00000000', traceIdString.substring(8, 16));
    expect(traceIdString.substring(16), isNot('0000000000000000'));
  });

  test('generateTracingContext generates proper bit values', () {
    final context = generateTracingContext(true);

    expect(context.traceId.value.bitLength, lessThanOrEqualTo(128));
    expect(context.spanId.value.bitLength, lessThanOrEqualTo(63));
    expect(context.sampled, true);
  });

  test('Datadog attributes generated correctly', () {
    final context = generateTracingContext(true);

    final attributes = generateDatadogAttributes(context, 30.0);

    expect(attributes['_dd.trace_id'],
        context.traceId.asString(TracingIdRepresentation.hex32Chars));
    expect(attributes['_dd.span_id'],
        context.spanId.asString(TracingIdRepresentation.decimal));
    expect(attributes['_dd.rule_psr'], 0.3);
  });

  test('Unsampled context does not generate datadog attributes', () {
    final context = generateTracingContext(false);

    final attributes = generateDatadogAttributes(context, 30.0);

    expect(attributes['_dd.trace_id'], isNull);
    expect(attributes['_dd.span_id'], isNull);
    expect(attributes['_dd.rule_psr'], 0.3);
  });

  // The TraceContextInjection value shouldn't matter in the sampled cases, so
  // make sure all tests work the same way for all TraceContextInjection options
  for (final contextInjection in TraceContextInjection.values) {
    test(
        'Datadog tracing headers are generated correctly { $contextInjection, sampled }',
        () {
      final context = generateTracingContext(true);

      final headers = getTracingHeaders(
        context,
        TracingHeaderType.datadog,
        contextInjection: contextInjection,
      );

      expect(headers['x-datadog-trace-id'],
          context.traceId.asString(TracingIdRepresentation.lowDecimal));
      expect(headers['x-datadog-tags'],
          '_dd.p.tid=${context.traceId.asString(TracingIdRepresentation.highHex16Chars)}');
      expect(headers['x-datadog-parent-id'],
          context.spanId.asString(TracingIdRepresentation.decimal));
      expect(headers['x-datadog-sampling-priority'], '1');
      expect(headers['x-datadog-origin'], 'rum');
    });

    test(
        'b3 tracing headers are generated correctly { $contextInjection, sampled }',
        () {
      final context = generateTracingContext(true);

      final headers = getTracingHeaders(
        context,
        TracingHeaderType.b3,
        contextInjection: contextInjection,
      );

      final traceString =
          context.traceId.asString(TracingIdRepresentation.hex32Chars);
      final spanString =
          context.spanId.asString(TracingIdRepresentation.hex16Chars);
      final expectedHeader = '$traceString-$spanString-1'.toLowerCase();

      expect(headers['b3'], expectedHeader);
    });

    test(
        'b3multi tracing headers are generated correctly { $contextInjection, sampled }',
        () {
      final context = generateTracingContext(true);

      final headers = getTracingHeaders(
        context,
        TracingHeaderType.b3multi,
        contextInjection: contextInjection,
      );

      final traceString =
          context.traceId.asString(TracingIdRepresentation.hex32Chars);
      final spanString =
          context.spanId.asString(TracingIdRepresentation.hex16Chars);

      expect(headers['X-B3-TraceId'], traceString.toLowerCase());
      expect(headers['X-B3-SpanId'], spanString.toLowerCase());
      expect(headers['X-B3-ParentSpanId'], isNull);
      expect(headers['X-B3-Sampled'], '1');
    });

    test(
        'tracecontext tracing headers are generated correctly { $contextInjection, sampled }',
        () {
      final context = generateTracingContext(true);

      final headers = getTracingHeaders(
        context,
        TracingHeaderType.tracecontext,
        contextInjection: contextInjection,
      );

      final traceString =
          context.traceId.asString(TracingIdRepresentation.hex32Chars);
      final spanString =
          context.spanId.asString(TracingIdRepresentation.hex16Chars);
      final expectedParentHeader = '00-$traceString-$spanString-01';
      final expectedStateHeader = 'dd=s:1;o:rum;p:$spanString';

      expect(headers['traceparent'], expectedParentHeader.toLowerCase());
      expect(headers['tracestate'], expectedStateHeader.toLowerCase());
    });
  }

  test(
      'Datadog tracing headers are generated correctly { TraceContextInjection.all, unsampled }',
      () {
    final context = generateTracingContext(false);

    final headers = getTracingHeaders(
      context,
      TracingHeaderType.datadog,
      contextInjection: TraceContextInjection.all,
    );

    expect(headers['x-datadog-trace-id'],
          context.traceId.asString(TracingIdRepresentation.lowDecimal));
      expect(headers['x-datadog-tags'],
          '_dd.p.tid=${context.traceId.asString(TracingIdRepresentation.highHex16Chars)}');
      expect(headers['x-datadog-parent-id'],
          context.spanId.asString(TracingIdRepresentation.decimal));
    expect(headers['x-datadog-sampling-priority'], '0');
    expect(headers['x-datadog-origin'], 'rum');
  });

  test(
      'Datadog tracing headers are generated correctly { TraceContextInjection.sampled, unsampled }',
      () {
    final context = generateTracingContext(false);

    final headers = getTracingHeaders(
      context,
      TracingHeaderType.datadog,
      contextInjection: TraceContextInjection.sampled,
    );

    expect(headers['x-datadog-trace-id'], isNull);
    expect(headers['x-datadog-parent-id'], isNull);
    expect(headers['x-datadog-sampling-priority'], isNull);
    expect(headers['x-datadog-origin'], isNull);
  });

  test(
      'b3 tracing headers are generated correctly { TraceContextInjection.all, unsampled }',
      () {
    final context = generateTracingContext(false);

    final headers = getTracingHeaders(
      context,
      TracingHeaderType.b3,
      contextInjection: TraceContextInjection.all,
    );

    expect(headers['b3'], '0');
  });

  test(
      'b3 tracing headers are generated correctly { TraceContextInjection.sampled, unsampled }',
      () {
    final context = generateTracingContext(false);

    final headers = getTracingHeaders(
      context,
      TracingHeaderType.b3,
      contextInjection: TraceContextInjection.sampled,
    );

    expect(headers['b3'], isNull);
  });

  test(
      'b3multi tracing headers are generated correctly { TraceContextInjection.all, unsampled }',
      () {
    final context = generateTracingContext(false);

    final headers = getTracingHeaders(
      context,
      TracingHeaderType.b3multi,
      contextInjection: TraceContextInjection.all,
    );

    expect(headers['X-B3-TraceId'], isNull);
    expect(headers['X-B3-SpanId'], isNull);
    expect(headers['X-B3-ParentSpanId'], isNull);
    expect(headers['X-B3-Sampled'], '0');
  });

  test(
      'b3multi tracing headers are generated correctly { TraceContextInjection.sampled, unsampled }',
      () {
    final context = generateTracingContext(false);

    final headers = getTracingHeaders(
      context,
      TracingHeaderType.b3multi,
      contextInjection: TraceContextInjection.sampled,
    );

    expect(headers['X-B3-TraceId'], isNull);
    expect(headers['X-B3-SpanId'], isNull);
    expect(headers['X-B3-ParentSpanId'], isNull);
    expect(headers['X-B3-Sampled'], isNull);
  });

  test(
      'traceparent tracing headers are generated correctly { TraceContextInjection.all, unsampled }',
      () {
    final context = generateTracingContext(false);

    final headers = getTracingHeaders(
      context,
      TracingHeaderType.tracecontext,
      contextInjection: TraceContextInjection.all,
    );

    final traceString =
        context.traceId.asString(TracingIdRepresentation.hex32Chars);
    final spanString =
        context.spanId.asString(TracingIdRepresentation.hex16Chars);
    final expectedParentHeader = '00-$traceString-$spanString-00';
    final expectedStateHeader = 'dd=s:0;o:rum;p:$spanString';

    expect(headers['traceparent'], expectedParentHeader.toLowerCase());
    expect(headers['tracestate'], expectedStateHeader.toLowerCase());
  });

  test(
      'traceparent tracing headers are generated correctly { TraceContextInjection.all, unsampled }',
      () {
    final context = generateTracingContext(false);

    final headers = getTracingHeaders(
      context,
      TracingHeaderType.tracecontext,
      contextInjection: TraceContextInjection.sampled,
    );

    expect(headers['traceparent'], isNull);
    expect(headers['tracestate'], isNull);
  });
}
