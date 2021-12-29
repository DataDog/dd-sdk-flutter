// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'dart:io';

import 'package:collection/collection.dart';

class SpanDecoder {
  final Map<String, Object?> envelope;
  final Map<String, Object?> span;

  String get environment => envelope['env'] as String;

  String get type => span['type'] as String;
  String get name => span['name'] as String;
  String get traceId => span['trace_id'] as String;
  String get spanId => span['span_id'] as String;
  String? get parentSpanId => span['parent_id'] as String?;
  String get resource => span['resource'] as String;
  int get isError => span['error'] as int;

  // Meta properties
  String get source => getNestedProperty('meta._dd.source');
  String get tracerVersion => getNestedProperty('meta.tracer.version');
  String get appVersion => getNestedProperty('meta.version');
  String get metaClass => getNestedProperty('meta.class');

  // Metrics properties
  int? get isRootSpan => getNestedProperty('metrics._top_level');

  SpanDecoder({required this.envelope, required this.span});

  T getTag<T>(String key) {
    if (Platform.isIOS) {
      return span['meta.$key'] as T;
    }
    return (span['meta'] as Map<String, dynamic>)[key] as T;
  }

  T getNestedProperty<T>(String key) {
    if (Platform.isIOS) {
      return span[key] as T;
    }

    var lookupMap = span;
    var parts = key.split('.');
    parts.forEachIndexedWhile((index, element) {
      lookupMap = lookupMap[element] as Map<String, dynamic>;
      // Continue until we're the second to last index
      return (index + 1) < (parts.length - 1);
    });

    return lookupMap[parts.last] as T;
  }
}
