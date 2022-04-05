// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

class DatadogTracingHeaders {
  static const traceId = 'x-datadog-trace-id';
  static const parentId = 'x-datadog-parent-id';
}

class DatadogPlatformAttributeKey {
  /// Trace ID. Used in RUM resources created by automatic resource tracking.
  /// Expects `String` value.
  static const traceID = '_dd.trace_id';

  /// Span ID. Used in RUM resources created by automatic resource tracking.
  /// Expects `String` value.
  static const spanID = '_dd.span_id';
}
