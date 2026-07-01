// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

/// Log levels defined by Datadog. Note that not all levels
/// are supported by the Flutter SDK currently, although any
/// level can be used for [DatadogLoggerConfiguration.remoteLogThreshold].
enum LogLevel {
  debug,
  info,

  /// Currently unsupported
  // ignore: unused_field
  notice,
  warning,
  error,

  /// Currently unsupported
  // ignore: unused_field
  critical,

  /// Currently unsupported
  // ignore: unused_field
  alert,

  /// Currently unsupported
  // ignore: unused_field
  emergency
}
