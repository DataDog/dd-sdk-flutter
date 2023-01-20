// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

class DatadogConfigKey {
  static const source = '_dd.source';
  static const sdkVersion = '_dd.sdk_version';
  static const nativeViewTracking = '_dd.native_view_tracking';
  static const version = '_dd.version';
  static const variant = '_dd.variant';
}

class DatadogPlatformAttributeKey {
  /// Custom SDK `source`. Used for all events issued by the SDK. It should
  /// replace the default native `ddSource` value (`"ios"`). Expects `String`
  /// value.
  static const ddSource = DatadogConfigKey.source;

  /// Custom "source type" of the error. Used in RUM errors. It names the
  /// language or platform of the RUM error stack trace, so the SCI backend
  /// knows how to symbolize it. Expects `String` value.
  static const errorSourceType = '_dd.error.source_type';
}
