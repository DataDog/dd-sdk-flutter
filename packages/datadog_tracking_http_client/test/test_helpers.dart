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

void verifyHeaders(Map<String, String> headers, TracingHeaderType type) {
  BigInt? traceInt;
  BigInt? spanInt;

  switch (type) {
    case TracingHeaderType.datadog:
      expect(headers['x-datadog-sampling-priority'], '1');
      traceInt = BigInt.tryParse(headers['x-datadog-trace-id']!);
      spanInt = BigInt.tryParse(headers['x-datadog-parent-id']!);
      final tagsHeader = headers['x-datadog-tags'];
      final parts = tagsHeader?.split('=');
      expect(parts, isNotNull);
      expect(parts?[0], '_dd.p.tid');
      BigInt? highTraceInt = BigInt.tryParse(parts?[1] ?? '', radix: 16);
      expect(highTraceInt, isNotNull);
      expect(highTraceInt?.bitLength, lessThanOrEqualTo(64));
      break;
    case TracingHeaderType.b3:
      var singleHeader = headers['b3']!;
      var headerParts = singleHeader.split('-');
      traceInt = BigInt.tryParse(headerParts[0], radix: 16);
      spanInt = BigInt.tryParse(headerParts[1], radix: 16);
      expect(headerParts[2], '1');
      break;
    case TracingHeaderType.b3multi:
      expect(headers['X-B3-Sampled'], '1');
      traceInt = BigInt.tryParse(headers['X-B3-TraceId']!, radix: 16);
      spanInt = BigInt.tryParse(headers['X-B3-SpanId']!, radix: 16);
      break;
    case TracingHeaderType.tracecontext:
      var header = headers['traceparent']!;
      var headerParts = header.split('-');
      expect(headerParts[0], '00');
      traceInt = BigInt.tryParse(headerParts[1], radix: 16);
      spanInt = BigInt.tryParse(headerParts[2], radix: 16);
      expect(headerParts[3], '01');

      final stateHeader = headers['tracestate']!;
      final stateParts = getDdTraceState(stateHeader);
      expect(stateParts['s'], '1');
      expect(stateParts['o'], 'rum');
      expect(stateParts['p'], headerParts[2]);
      break;
  }

  expect(traceInt, isNotNull);
  if (type == TracingHeaderType.datadog) {
    expect(traceInt?.bitLength, lessThanOrEqualTo(64));
  } else {
    expect(traceInt?.bitLength, lessThanOrEqualTo(128));
  }

  expect(spanInt, isNotNull);
  expect(spanInt?.bitLength, lessThanOrEqualTo(63));
}
