// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

extension HttpHeadersToMap on HttpHeaders {
  Map<String, String> toMap() {
    Map<String, String> map = {};
    forEach((name, values) {
      map[name] = values.join(',');
    });

    return map;
  }
}

void verifyHeaders(Map<String, String> headers, TracingHeaderType type,
    bool sampled, TraceContextInjection traceContextInjection) {
  BigInt? traceInt;
  BigInt? spanInt;

  bool shouldInjectHeaders =
      sampled || traceContextInjection == TraceContextInjection.all;

  switch (type) {
    case TracingHeaderType.datadog:
      if (shouldInjectHeaders) {
        expect(headers['x-datadog-sampling-priority'], sampled ? '1' : '0');
        traceInt = BigInt.tryParse(headers['x-datadog-trace-id']!);
        spanInt = BigInt.tryParse(headers['x-datadog-parent-id']!);
        final tagsHeader = headers['x-datadog-tags'];
        final parts = tagsHeader?.split('=');
        expect(parts, isNotNull);
        expect(parts?[0], '_dd.p.tid');
        BigInt? highTraceInt = BigInt.tryParse(parts?[1] ?? '', radix: 16);
        expect(highTraceInt, isNotNull);
        expect(highTraceInt?.bitLength, lessThanOrEqualTo(64));
      } else {
        expect(headers['x-datadog-origin'], isNull);
        expect(headers['x-datadog-sampling-priority'], isNull);
        expect(headers['x-datadog-trace-id'], isNull);
        expect(headers['x-datadog-parent-id'], isNull);
        expect(headers['x-datadog-tags'], isNull);
      }
      break;
    case TracingHeaderType.b3:
      var singleHeader = headers['b3'];
      if (sampled) {
        var headerParts = singleHeader!.split('-');
        traceInt = BigInt.tryParse(headerParts[0], radix: 16);
        spanInt = BigInt.tryParse(headerParts[1], radix: 16);
        expect(headerParts[2], sampled ? '1' : '0');
      } else if (shouldInjectHeaders) {
        expect(singleHeader, '0');
      } else {
        expect(singleHeader, isNull);
      }
      break;
    case TracingHeaderType.b3multi:
      if (shouldInjectHeaders) {
        expect(headers['X-B3-Sampled'], sampled ? '1' : '0');
        if (sampled) {
          traceInt = BigInt.tryParse(headers['X-B3-TraceId']!, radix: 16);
          spanInt = BigInt.tryParse(headers['X-B3-SpanId']!, radix: 16);
        }
      } else {
        expect(headers['X-B3-Sampled'], isNull);
        expect(headers['X-B3-TraceId'], isNull);
        expect(headers['X-B3-SpanId'], isNull);
      }
      break;
    case TracingHeaderType.tracecontext:
      if (shouldInjectHeaders) {
        var header = headers['traceparent']!;
        var headerParts = header.split('-');
        expect(headerParts[0], '00');
        traceInt = BigInt.tryParse(headerParts[1], radix: 16);
        spanInt = BigInt.tryParse(headerParts[2], radix: 16);
        expect(headerParts[3], sampled ? '01' : '00');

        final stateHeader = headers['tracestate']!;
        final stateParts = getDdTraceState(stateHeader);
        expect(stateParts['s'], sampled ? '1' : '0');
        expect(stateParts['o'], 'rum');
        expect(stateParts['p'], headerParts[2]);
      } else {
        expect(headers['traceparent'], isNull);
      }
      break;
  }

  if (sampled) {
    expect(traceInt, isNotNull);
  }
  if (traceInt != null) {
    if (type == TracingHeaderType.datadog) {
      expect(traceInt.bitLength, lessThanOrEqualTo(64));
    } else {
      expect(traceInt.bitLength, lessThanOrEqualTo(128));
    }
  }

  if (sampled) {
    expect(spanInt, isNotNull);
  }
  if (spanInt != null) {
    expect(spanInt.bitLength, lessThanOrEqualTo(63));
  }
}
