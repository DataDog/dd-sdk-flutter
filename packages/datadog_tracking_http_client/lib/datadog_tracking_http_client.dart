// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

import 'src/tracking_http_client_plugin.dart';

export 'src/tracing_headers.dart';
export 'src/tracking_http_client.dart';

extension TrackingExtension on DdSdkConfiguration {
  /// Configures network requests monitoring for Tracing and RUM features.
  ///
  /// If enabled, the SDK will override [HttpClient] creation (via
  /// [HttpOverrides]) to provide its own implementation. For more information,
  /// check the documentation on [DatadogTrackingHttpClient]
  ///
  /// If the RUM feature is enabled, the SDK will send RUM Resources for all
  /// intercepted requests.
  ///
  /// If the Tracing feature is enabled, the SDK will send tracing Span for each
  /// 1st-party request. It will also add extra HTTP headers to further
  /// propagate the trace - it means that if your backend is instrumented with
  /// Datadog agent you will see the full trace (e.g.: client → server →
  /// database) in your dashboard, thanks to Datadog Distributed Tracing.
  ///
  /// If both RUM and Tracing features are enabled, the SDK will be sending RUM
  /// Resources for 1st- and 3rd-party requests and tracing Spans for
  /// 1st-parties.
  ///
  /// See also [firstPartyHosts]
  void enableHttpTracking() {
    addPlugin(DdHttpTrackingPluginConfiguration());
  }
}
