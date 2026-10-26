// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

/// A set of properties that Flutter can configure "late", meaning after the
/// first call to [DatadogSdk.initialize].
enum LateConfigurationProperty {
  /// Whether the user is tracking views manually. This is set to false if a
  /// DatadogNavigationObserver is constructed.
  trackViewsManually,

  /// Whether the user is using [RumUserActionDetector]. Set when the first
  /// [RumUserActionDetector] is constructed.
  trackInteractions,

  /// Whether Datadog is automatically tracking errors, set if
  /// [DatadogSdk.runApp] is used.
  trackErrors,

  /// Whether or not network requests are being tracked. Set during initialization
  /// of the datadog_tracking_http_client HttpClient or http.Client classes.
  trackNetworkRequests,

  /// Whether we are tracking cross platform long tasks. This is currently
  /// always the same as trackLongTasks
  trackCrossPlatformLongTasks,

  /// Whether native views are being tracked. Currently unused.
  trackNativeViews,

  /// Whether [DatadogRumConfiguration.reportFlutterPerformance] was set to true
  trackFlutterPerformance,
}
