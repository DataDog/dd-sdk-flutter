// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

class DatadogTracingHeaders {
  static const traceId = 'x-datadog-trace-id';
  static const parentId = 'x-datadog-parent-id';

  static const samplingPriority = 'x-datadog-sampling-priority';
  static const origin = 'x-datadog-origin';
}

class DatadogRumPlatformAttributeKey {
  /// Trace ID. Used in RUM resources created by automatic resource tracking.
  /// Expects `String` value.
  static const traceID = '_dd.trace_id';

  /// Span ID. Used in RUM resources created by automatic resource tracking.
  /// Expects `String` value.
  static const spanID = '_dd.span_id';

  /// Trace sample rate applied to RUM resources created by cross platform SDK.
  /// We send cross-platform SDK's sample rate within RUM resource in order to provide accurate visibility into what settings are
  /// configured at the SDK level. This gets displayed on APM's traffic ingestion control page.
  /// Expects `double` value between `0.0` and `1.0`.
  static const rulePsr = '_dd.rule_psr';
}
