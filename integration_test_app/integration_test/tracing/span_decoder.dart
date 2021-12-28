// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

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
  String get source => span['meta._dd.source'] as String;
  String get tracerVersion => span['meta.tracer.version'] as String;
  String get appVersion => span['meta.version'] as String;

  // Metrics properties
  int? get isRootSpan => span['metrics._top_level'] as int?;

  SpanDecoder({required this.envelope, required this.span});
}
