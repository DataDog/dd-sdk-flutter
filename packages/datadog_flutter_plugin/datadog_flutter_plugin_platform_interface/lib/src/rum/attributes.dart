// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

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

  /// Internal attribute that specifies with the first build of a Flutter view is complete.
  static const firstBuildComplete = '_dd.performance.first_build_complete';

  /// Internal view attribute that specifies the "Interaction To Next View" timing.
  static const customInvValue = '_dd.view.custom_inv_value';

  /// Captured HTTP request headers. Used in RUM resources created by automatic
  /// resource tracking. Expects `Map<String, String>` value.
  static const requestHeaders = '_dd.request_headers';

  /// Captured HTTP response headers. Used in RUM resources created by automatic
  /// resource tracking. Expects `Map<String, String>` value.
  static const responseHeaders = '_dd.response_headers';
}
