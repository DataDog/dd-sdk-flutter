// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

/// Internal interface to provide the current timestamp for events, either in
/// milliseconds (the default for most events) or nanoseconds (the default
/// for some performance events).
abstract interface class DatadogTimeProvider {
  int nowMs();
  int nowNs();
  DateTime now();
}

/// Default time provider which uses `DateTime` to provide the current timestamp.
class DefaultTimeProvider implements DatadogTimeProvider {
  const DefaultTimeProvider();

  @override
  int nowMs() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  @override
  int nowNs() {
    /// Note, Dart only has precision up to the microsecond level, so the last
    /// digits of this value will always be zero.
    return DateTime.now().microsecondsSinceEpoch * 1000;
  }

  @override
  DateTime now() {
    return DateTime.now();
  }
}
