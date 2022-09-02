// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:math';

import '../datadog_flutter_plugin.dart';

/// Defines the Datadog SDK policy when batching data together before uploading
/// it to Datadog servers. Smaller batches mean smaller but more network
/// requests, whereas larger batches mean fewer but larger network requests.
enum BatchSize {
  /// Prefer small sized data batches.
  small,

  /// Prefer medium sized data batches.
  medium,

  /// Prefer large sized data batches.
  large
}

/// Defines the frequency at which Datadog SDK will try to upload data batches.
enum UploadFrequency {
  /// Try to upload batched data frequently.
  frequent,

  /// Try to upload batched data with a medium frequently.
  average,

  /// Try to upload batched data rarely.
  rare
}

/// Possible values for the Data Tracking Consent given by the user of the app.
///
/// This value should be used to grant the permission for Datadog SDK to store
/// data collected in Logging, Tracing or RUM and upload it to Datadog servers.
enum TrackingConsent {
  /// The permission to persist and send data to the Datadog servers was
  /// granted. Any previously stored pending data will be marked as ready for
  /// sent.
  granted,

  /// Any previously stored pending data will be deleted and all Logging, RUM
  /// and Tracing events will be dropped from now on, without persisting it in
  /// any way.
  notGranted,

  /// All Logging, RUM and Tracing events will be persisted in an intermediate
  /// location and will be pending there until [TrackingConsent.granted] or
  /// [TrackingConsent.notGranted] consent value is set. Based on the next
  /// consent value, intermediate data will be sent to Datadog or deleted.
  pending
}

/// Determines the server for uploading RUM events.
enum DatadogSite {
  /// US based servers. Sends RUM events to
  /// [app.datadoghq.com](https://app.datadoghq.com/).
  us1,

  /// US based servers. Sends RUM events to
  /// [app.datadoghq.com](https://us3.datadoghq.com/).
  us3,

  /// US based servers. Sends RUM events to
  /// [app.datadoghq.com](https://us5.datadoghq.com/).
  us5,

  /// Europe based servers. Sends RUM events to
  /// [app.datadoghq.eu](https://app.datadoghq.eu/).
  eu1,

  /// US based servers, FedRAMP compatible. Sends RUM events to
  /// [app.ddog-gov.com](https://app.ddog-gov.com/).
  us1Fed
}

enum Verbosity { verbose, debug, info, warn, error, none }

/// Configuration options for the Datadog Logging feature.
class LoggingConfiguration {
  /// Enriches logs with network connection info. This means: reachability
  /// status, connection type, mobile carrier name and many more will be added to
  /// each log.
  ///
  /// Defaults to `false`.
  bool sendNetworkInfo;

  /// Enables logs to be printed to debugger console for debug build
  ///
  /// Defaults to `false`.
  bool printLogsToConsole;

  /// Enables or disables sending logs to Datadog.
  ///
  /// Defaults to `true`.
  bool sendLogsToDatadog;

  /// Sets the level of logs that get sent to Datadog
  ///
  /// Logs below the configured threshold are not sent to Datadog, while
  /// logs at this threshold and above are, so long as [sendLogsToDatadog]
  /// is also set.
  ///
  /// Defaults to [Verbosity.verbose]
  Verbosity datadogReportingThreshold;

  /// Enables the logs integration with RUM.
  ///
  /// If enabled, all the logs will be enriched with the current RUM View
  /// information and it will be possible to see all the logs sent during a
  /// specific View lifespan in the RUM Explorer.
  ///
  /// Defaults to `true`.
  bool bundleWithRum;

  /// Enables the logs integration with active span API from Tracing.
  ///
  /// If enabled, all the logs will be bundled with the `activeSpan` trace and
  /// it will be possible to see all the logs sent during that specific trace.
  ///
  /// Default to `true`.
  bool bundleWithTrace;

  /// Sets the name of the logger.
  ///
  /// This name will be set as the `logger.name` attribute attached to all logs
  /// sent to Datadog from this logger.
  String? loggerName;

  LoggingConfiguration({
    this.sendNetworkInfo = false,
    this.printLogsToConsole = false,
    this.sendLogsToDatadog = true,
    this.datadogReportingThreshold = Verbosity.verbose,
    this.bundleWithRum = true,
    this.bundleWithTrace = true,
    this.loggerName,
  });

  Map<String, Object?> encode() {
    return {
      'sendNetworkInfo': sendNetworkInfo,
      'printLogsToConsole': printLogsToConsole,
      'sendLogsToDatadog': sendLogsToDatadog,
      'bundleWithRum': bundleWithRum,
      'loggerName': loggerName,
    };
  }
}

/// Configuration options for the Datadog Real User Monitoring (RUM) feature.
class RumConfiguration {
  // Either a RUM Application Id. Obtained on the Datadog website.
  String applicationId;

  /// Sets the sampling rate for RUM Sessions.
  ///
  /// This property is deprecated in favor of [sessionSamplingRate]
  @Deprecated('Use sessionSamplingRate instead')
  double get sampleRate => sessionSamplingRate;
  set sampleRate(double value) => sessionSamplingRate = value;

  /// Sets the sampling rate for RUM Sessions.
  ///
  /// The sampling rate must be a value between `0.0` and `100.0`. A value of
  /// `0.0` means no RUM events will be sent, `100.0` means all sessions will be
  /// sent
  ///
  /// Defaults to `100.0`.
  double sessionSamplingRate;

  /// Sets the sampling rate for tracing
  ///
  /// The sampling rate must be a value between `0.0` and `100.0`. A value of
  /// `0.0` means no resources will include APM tracing, `100.0` resource will
  /// include APM tracing
  ///
  /// Defaults to `20.0`.
  double tracingSamplingRate;

  /// Enable or disable detection of "long tasks"
  ///
  /// Long task detection attempts to detect when an application is doing too
  /// much work on the main isolate, or on the main native thread, which could
  /// prevent your app from rendering at a smooth framerate.
  ///
  /// Defaults to true.
  bool detectLongTasks;

  /// The amount of elapsed time that is considered to be a "long task", in
  /// seconds.
  ///
  /// If the main isolate takes more than [longTaskThreshold] seconds to process
  /// a microtask, it will appear as a Long Task in Datadog RUM Explorer. This
  /// has a minimum of 0.02 seconds.
  ///
  /// The Datadog iOS and Android SDKs will also report if their main threads
  /// are stalled for longer than this threshold, and will also appear as a
  /// Long Task in the Datadog RUM Explorer
  ///
  /// Defaults to 0.1 seconds
  double longTaskThreshold;

  /// Use a custom endpoint for sending RUM data.
  String? customEndpoint;

  RumConfiguration({
    required this.applicationId,
    double sessionSamplingRate = 100.0,
    double tracingSamplingRate = 20.0,
    this.detectLongTasks = true,
    double longTaskThreshold = 0.1,
    this.customEndpoint,
  })  : sessionSamplingRate = max(0, min(sessionSamplingRate, 100)),
        tracingSamplingRate = max(0, min(tracingSamplingRate, 100)),
        longTaskThreshold = max(0.02, longTaskThreshold);

  Map<String, Object?> encode() {
    return {
      'applicationId': applicationId,
      'sampleRate': sessionSamplingRate,
      'detectLongTasks': detectLongTasks,
      'longTaskThreshold': longTaskThreshold,
      'customEndpoint': customEndpoint,
    };
  }
}

class DdSdkConfiguration {
  // Either a RUM client token (generated for the RUM Application) or a regular
  // client token for Logging and APM. Obtained on the Datadog website.
  String clientToken;

  /// The environment name which will be sent to Datadog. This can be used to
  /// filter events on different environments (e.g. "staging" or "production").
  String env;

  /// Whether or not to enable native crash reporting.
  bool nativeCrashReportEnabled;

  /// The [DatadogSite] to send information to. This site must match the site
  /// used to generate your client token.
  DatadogSite site;

  /// Use a custom endpoint for logs
  String? customLogsEndpoint;

  /// The service name for this application
  String? serviceName;

  /// The initial [TrackingConsent] for this user.
  TrackingConsent trackingConsent;

  /// Sets the preferred size of batched data uploaded to Datadog servers. This
  /// value impacts the size and number of requests performed by the SDK.
  BatchSize? batchSize;

  /// Sets the preferred frequency of uploading data to Datadog servers. This
  /// value impacts the frequency of performing network requests by the SDK.
  UploadFrequency? uploadFrequency;

  /// Set a custom endpoint to send information to.
  ///
  /// This is deprecated in favor of [customLogsEndpoint] and
  /// [RumConfiguration.customEndpoint].
  @Deprecated(
      'Use customLogsEndpoint and RumConfiguration.customEndpoint instead')
  String? customEndpoint;

  /// The sampling rate for Internal Telemetry (info related to the work of the
  /// SDK internals).
  ///
  /// The sampling rate must be a value between 0 and 100. A value of 0 means no
  /// telemetry will be sent, 100 means all telemetry will be sent. When
  /// [telemetrySampleRate] is set to null, the default value from the iOS and
  /// Android SDK is used, which is 20.
  double? telemetrySampleRate;

  /// A list of first party hosts, used in conjunction with [trackHttpClient]
  ///
  /// Each request will be classified as 1st- or 3rd-party based on the host
  /// comparison, i.e.:
  /// * if `firstPartyHosts` is `["example.com"]`:
  ///     - 1st-party URL examples: https://example.com/,
  ///       https://api.example.com/v2/users
  ///     - 3rd-party URL examples: https://foo.com/, https://example.net
  /// * if `firstPartyHosts` is `["api.example.com"]`:
  ///     - 1st-party URL examples: https://api.example.com/,
  ///       https://api.example.com/v2/users,
  ///       https://beta.api.example.com/v2/users
  ///     - 3rd-party URL examples: https://example.com/, https://foo.com/,
  ///       https://api.example.net/v3/users
  ///
  List<String> firstPartyHosts = [];

  /// Configuration for the logging feature. If this configuration is null,
  /// logging is disabled.
  LoggingConfiguration? loggingConfiguration;

  /// Configuration for the Real User Monitoring (RUM) feature. If this
  /// configuration is null, RUM is disabled
  RumConfiguration? rumConfiguration;

  /// Any additional configuration to be passed to the native SDKs
  final Map<String, Object?> additionalConfig = {};

  /// Configurations for additional plugins that will be created after Datadog
  /// is initialized.
  final List<DatadogPluginConfiguration> additionalPlugins = [];

  DdSdkConfiguration({
    required this.clientToken,
    required this.env,
    required this.trackingConsent,
    required this.site,
    this.customLogsEndpoint,
    this.nativeCrashReportEnabled = false,
    this.serviceName,
    this.uploadFrequency,
    this.batchSize,
    this.customEndpoint,
    this.telemetrySampleRate,
    this.firstPartyHosts = const [],
    this.loggingConfiguration,
    this.rumConfiguration,
  }) {
    // Transfer customEndpoint to other properties if they're not set
    // ignore: deprecated_member_use_from_same_package
    if (customEndpoint != null) {
      // ignore: deprecated_member_use_from_same_package
      customLogsEndpoint ??= customEndpoint;
      if (rumConfiguration != null &&
          rumConfiguration?.customEndpoint == null) {
        // ignore: deprecated_member_use_from_same_package
        rumConfiguration?.customEndpoint = customEndpoint;
      }
    }
  }

  void addPlugin(DatadogPluginConfiguration pluginConfiguration) =>
      additionalPlugins.add(pluginConfiguration);

  Map<String, Object?> encode() {
    return {
      'clientToken': clientToken,
      'env': env,
      'nativeCrashReportEnabled': nativeCrashReportEnabled,
      'site': site.toString(),
      'serviceName': serviceName,
      'batchSize': batchSize?.toString(),
      'telemetrySampleRate': telemetrySampleRate,
      'uploadFrequency': uploadFrequency?.toString(),
      'trackingConsent': trackingConsent.toString(),
      'firstPartyHosts': firstPartyHosts,
      'rumConfiguration': rumConfiguration?.encode(),
      'additionalConfig': additionalConfig,
      'customLogsEndpoint': customLogsEndpoint,
    };
  }
}
