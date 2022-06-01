// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'dart:io';

import 'package:datadog_common_test/datadog_common_test.dart';

class SpanDecoder {
  final Map<String, Object?> envelope;
  final Map<String, Object?> span;

  String get environment => envelope['env'] as String;

  String get type => span['type'] as String;
  String get name => span['name'] as String;
  String get traceId => span['trace_id'] as String;
  String get spanId => span['span_id'] as String;
  int get duration => (span['duration'] as num).toInt();
  String? get parentSpanId => span['parent_id'] as String?;
  String get resource => span['resource'] as String;
  int get isError => span['error'] as int;

  // Meta properties
  String get source => getNestedProperty('meta._dd.source', span);
  String get tracerVersion => getNestedProperty('meta.tracer.version', span);
  String get appVersion => getNestedProperty('meta.version', span);
  String get metaClass => getNestedProperty('meta.class', span);

  // Metrics properties
  int? get isRootSpan => getNestedProperty('metrics._top_level', span);

  SpanDecoder({required this.envelope, required this.span});

  T getTag<T>(String key) {
    if (Platform.isIOS) {
      return span['meta.$key'] as T;
    }
    return (span['meta'] as Map<String, dynamic>)[key] as T;
  }
}
