// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

import 'src/tracking_http_client_plugin.dart'
    show DdHttpTrackingPluginConfiguration;

export 'src/tracking_http.dart';
export 'src/tracking_http_client.dart';

extension TrackingExtension on DdSdkConfiguration {
  /// Configures network requests monitoring for Tracing and RUM features.
  ///
  /// If enabled, the SDK will override [HttpClient] creation (via
  /// [HttpOverrides]) to provide its own implementation. For more information,
  /// check the documentation on [DatadogTrackingHttpClient]
  ///
  /// If the RUM feature is enabled, the SDK will send RUM Resources for all
  /// intercepted requests. The SDK will also generate and send tracing Spans
  /// for each 1st-party request.
  ///
  /// The DatadogTracingHttpClient can additionally set tracing headers on your
  /// requests, which allows for distributed tracing. You can set which format
  /// of tracing headers when configuring firstParty hosts with
  /// [DdSdkConfiguration.firstPartyHostsWithTracingHeaders]. The percentage of
  /// resources traced in this way is determined by
  /// [RumConfiguration.tracingSamplingRate].
  ///
  ///
  /// Note that this is call is not necessary if you only want to track requests
  /// made through [DatadogClient]
  ///
  /// See also [DdSdkConfiguration.firstPartyHostsWithTracingHeaders],
  /// [DdSdkConfiguration.firstPartyHosts], [TracingHeaderType]
  void enableHttpTracking() {
    addPlugin(DdHttpTrackingPluginConfiguration());
  }
}

extension TrackingExtensionExisting on DdSdkExistingConfiguration {
  /// See [TrackingExtension.enableHttpTracking]
  void enableHttpTracking() {
    addPlugin(DdHttpTrackingPluginConfiguration());
  }
}
