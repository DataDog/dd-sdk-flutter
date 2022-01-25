// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

enum BatchSize { small, medium, large }
enum UploadFrequency { frequent, average, rare }
enum TrackingConsent { granted, notGranted, pending }
enum DatadogSite { us1, us3, us5, eu1, us1Fed }
enum Verbosity { debug, info, warn, error, none }

class LoggingConfiguration {
  bool sendNetworkInfo;
  bool printLogsToConsole;
  bool bundleWithRum;
  bool bundleWithTrace;

  LoggingConfiguration({
    this.sendNetworkInfo = false,
    this.printLogsToConsole = false,
    this.bundleWithRum = true,
    this.bundleWithTrace = true,
  });

  Map<String, dynamic> encode() {
    return {
      'sendNetworkInfo': sendNetworkInfo,
      'printLogsToConsole': printLogsToConsole,
      'bundleWithRum': bundleWithRum,
      'bundleWithTrace': bundleWithTrace,
    };
  }
}

class TracingConfiguration {
  bool sendNetworkInfo;
  bool bundleWithRum;

  TracingConfiguration({
    this.sendNetworkInfo = false,
    this.bundleWithRum = true,
  });

  Map<String, dynamic> encode() {
    return {
      'sendNetworkInfo': sendNetworkInfo,
      'bundleWithRum': bundleWithRum,
    };
  }
}

class RumConfiguration {
  String applicationId;
  double sampleRate;

  RumConfiguration({
    required this.applicationId,
    this.sampleRate = 100.0,
  });

  Map<String, dynamic> encode() {
    return {
      'applicationId': applicationId,
      'sampleRate': sampleRate,
    };
  }
}

class DdSdkConfiguration {
  String clientToken;
  String env;
  bool nativeCrashReportEnabled;
  DatadogSite? site;
  TrackingConsent trackingConsent;
  BatchSize? batchSize;
  UploadFrequency? uploadFrequency;
  String? customEndpoint;

  /// Configures network requests monitoring for Tracing and RUM features.
  ///
  /// If set, the SDK will override [HttpClient] creation (via [HttpOverrides])
  /// to provide its own implementation. For more information, check the
  /// documentation on  [DatadogTrackingHttpClient]
  ///
  /// If the RUM feature is enabled, the SDK will send RUM Resources for all
  /// intercepted requests.
  ///
  /// If Tracing feature is enabled, the SDK will send tracing Span for each
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
  bool trackHttpClient;

  /// A list of first party hosts, used in conjunction with [trackHttpClient]
  ///
  /// Each request will be classified as 1st- or 3rd-party based on the host
  /// comparison, i.e.:
  /// * if `firstPartyHosts` is `["example.com"]`:
  ///     - 1st-party URL examples: https://example.com/,
  ///       https://api.example.com/v2/users
  ///     - 3rd-party URL examples: https://foo.com/
  /// * if `firstPartyHosts` is `["api.example.com"]`:
  ///     - 1st-party URL examples: https://api.example.com/,
  ///       https://api.example.com/v2/users
  ///     - 3rd-party URL examples: https://example.com/, https://foo.com/
  ///
  List<String> firstPartyHosts = [];

  LoggingConfiguration? loggingConfiguration;
  TracingConfiguration? tracingConfiguration;
  RumConfiguration? rumConfiguration;

  final Map<String, dynamic> additionalConfig = {};

  DdSdkConfiguration({
    required this.clientToken,
    required this.env,
    required this.trackingConsent,
    this.nativeCrashReportEnabled = false,
    this.site,
    this.uploadFrequency,
    this.batchSize,
    this.customEndpoint,
    this.trackHttpClient = false,
    this.firstPartyHosts = const [],
    this.loggingConfiguration,
    this.tracingConfiguration,
    this.rumConfiguration,
  });

  Map<String, dynamic> encode() {
    return {
      'clientToken': clientToken,
      'env': env,
      'nativeCrashReportEnabled': nativeCrashReportEnabled,
      'site': site?.toString(),
      'batchSize': batchSize?.toString(),
      'uploadFrequency': uploadFrequency?.toString(),
      'trackingConsent': trackingConsent.toString(),
      'customEndpoint': customEndpoint,
      'loggingConfiguration': loggingConfiguration?.encode(),
      'tracingConfiguration': tracingConfiguration?.encode(),
      'rumConfiguration': rumConfiguration?.encode(),
      'additionalConfig': additionalConfig
    };
  }
}
