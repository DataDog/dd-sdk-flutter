// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

/// The type of tracing header to inject into first party requests.
enum TracingHeaderType {
  /// [Datadog's `x-datadog-*` header](https://docs.datadoghq.com/real_user_monitoring/connect_rum_and_traces/?tab=browserrum#how-are-rum-resources-linked-to-traces).
  datadog,

  /// Open Telemetry B3 [Single header](https://github.com/openzipkin/b3-propagation#single-headers).
  b3,

  /// Open Telemetry B3 [Multiple headers](https://github.com/openzipkin/b3-propagation#multiple-headers).
  b3multi,

  /// W3C [Trace Context header](https://www.w3.org/TR/trace-context/#tracestate-header)
  tracecontext,
}
