// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:math';

import 'package:meta/meta.dart';

import '../datadog_flutter_plugin.dart';
import '../datadog_internal.dart';

/// A function that allows you to modify or drop specific [LogEvent]s before
/// they are sent to Datadog.
///
/// The [LogEventMapper] can modify any mutable (non-final) properties in the
/// [LogEvent], or return null to drop the log entirely.
typedef LogEventMapper = LogEvent? Function(LogEvent event);

/// A function that allows you to modify specific [RumViewEvent]s before they
/// are sent to Datadog.
///
/// The [RumViewEventMapper] can modify any mutable (non-final) properties in
/// the [RumViewEvent]
typedef RumViewEventMapper = RumViewEvent Function(RumViewEvent event);

/// A function that allows you to modify or drop specific [RumActionEvent]s before
/// they are sent to Datadog.
///
/// The [RumActionEventMapper] can modify any mutable (non-final) properties in the
/// [RumActionEvent]
typedef RumActionEventMapper = RumActionEvent? Function(RumActionEvent event);

/// A function that allows you to modify or drop specific [RumResourceEvent]s before
/// they are sent to Datadog.
///
/// The [RumResourceEventMapper] can modify any mutable (non-final) properties in the
/// [RumResourceEvent]
typedef RumResourceEventMapper = RumResourceEvent? Function(
    RumResourceEvent event);

/// A function that allows you to modify or drop specific [RumErrorEvent]s before
/// they are sent to Datadog.
///
/// The [RumErrorEventMapper] can modify any mutable (non-final) properties in the
/// [RumErrorEvent]
typedef RumErrorEventMapper = RumErrorEvent? Function(RumErrorEvent event);

/// A function that allows you to modify or drop specific [RumLongTaskEvent]s before
/// they are sent to Datadog.
///
/// The [RumLongTaskEvent] can modify any mutable (non-final) properties in the
/// [RumLongTaskEvent]
typedef RumLongTaskEventMapper = RumLongTaskEvent? Function(
    RumLongTaskEvent event);

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
/// data collected in Logging / RUM and upload it to Datadog servers.
enum TrackingConsent {
  /// The permission to persist and send data to the Datadog servers was
  /// granted. Any previously stored pending data will be marked as ready for
  /// sent.
  granted,

  /// Any previously stored pending data will be deleted and all Logging and RUM
  /// events will be dropped from now on, without persisting it in any way.
  notGranted,

  /// All Logging and RUM events will be persisted in an intermediate location
  /// and will be pending there until [TrackingConsent.granted] or
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
  /// [us3.datadoghq.com](https://us3.datadoghq.com/).
  us3,

  /// US based servers. Sends RUM events to
  /// [us5.datadoghq.com](https://us5.datadoghq.com/).
  us5,

  /// Europe based servers. Sends RUM events to
  /// [app.datadoghq.eu](https://app.datadoghq.eu/).
  eu1,

  /// US based servers, FedRAMP compatible. Sends RUM events to
  /// [app.ddog-gov.com](https://app.ddog-gov.com/).
  us1Fed,

  /// Asia baesd servers. Sends data to
  /// [ap1.datadoghq.com](https://ap1.datadoghq.com).
  ap1,
}

enum Verbosity {
  verbose,
  debug,
  info,
  notice,
  warn,
  error,
  critical,
  alert,
  emergency,
  none
}

/// Defines the frequency at which Datadog SDK will collect mobile vitals, such
/// as CPU and memory usage.
enum VitalsFrequency {
  /// Collect mobile vitals every 100ms.
  frequent,

  /// Collect mobile vitals every 500ms.
  average,

  /// Collect mobile vitals every 1000ms.
  rare,

  /// Don't provide mobile vitals.
  never,
}

/// Configuration options for the Datadog Logging feature.
class LoggingConfiguration {
  /// Enriches logs with network connection info. This means: reachability
  /// status, connection type, mobile carrier name and many more will be added
  /// to each log.
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
  /// Logs below the configured threshold are not sent to Datadog, while logs at
  /// this threshold and above are, so long as [sendLogsToDatadog] is also set.
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

  /// Sets the sampling rate for resource tracing
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
  /// are stalled for longer than this threshold, and will also appear as a Long
  /// Task in the Datadog RUM Explorer
  ///
  /// Note -- this argument is ignored on Flutter Web, which always uses a value
  /// of 0.05 seconds (50ms).  See documentation on [RUM Browser
  /// Monitoring](https://docs.datadoghq.com/real_user_monitoring/browser/data_collected/)
  ///
  /// Defaults to 0.1 seconds
  double longTaskThreshold;

  /// Sets the preferred frequency for collecting mobile vitals.
  ///
  /// Note this setting does not affect the sampling done by [reportFlutterPerformance].
  ///
  /// Defaults to [VitalsFrequency.average]
  VitalsFrequency vitalUpdateFrequency;

  /// Whether to report Flutter specific performance metrics (build and raster
  /// times)
  ///
  /// This uses the [SchedulerBinding.addTimingsCallback] method to report build
  /// and raster times for views, and has a documented negligible impact on
  /// performance.
  ///
  /// Defaults to false
  bool reportFlutterPerformance = false;

  /// Use a custom endpoint for sending RUM data.
  String? customEndpoint;

  /// A function that allows you to modify or drop specific [RumViewEvent]s
  /// before they are sent to Datadog.
  RumViewEventMapper? rumViewEventMapper;

  /// A function that allows you to modify or drop specific [RumActionEvent]s
  /// before they are sent to Datadog.
  RumActionEventMapper? rumActionEventMapper;

  /// A function that allows you to modify or drop specific [RumResourceEvent]s
  /// before they are sent to Datadog.
  RumResourceEventMapper? rumResourceEventMapper;

  /// A function that allows you to modify or drop specific [RumResourceEvent]s
  /// before they are sent to Datadog.
  RumErrorEventMapper? rumErrorEventMapper;

  /// A function that allows you to modify or drop specific [RumLongTaskEvent]s
  /// before they are sent to Datadog.
  RumLongTaskEventMapper? rumLongTaskEventMapper;

  RumConfiguration({
    required this.applicationId,
    double sessionSamplingRate = 100.0,
    double tracingSamplingRate = 20.0,
    this.detectLongTasks = true,
    double longTaskThreshold = 0.1,
    this.vitalUpdateFrequency = VitalsFrequency.average,
    this.reportFlutterPerformance = false,
    this.customEndpoint,
    this.rumViewEventMapper,
    this.rumActionEventMapper,
    this.rumResourceEventMapper,
    this.rumErrorEventMapper,
    this.rumLongTaskEventMapper,
  })  : sessionSamplingRate = max(0, min(sessionSamplingRate, 100)),
        tracingSamplingRate = max(0, min(tracingSamplingRate, 100)),
        longTaskThreshold = max(0.02, longTaskThreshold);

  /// Create a configuration that stands in for the configuration that already
  /// occurred from an existing instance.
  ///
  /// This method is meant for internal Datadog use only.
  @internal
  RumConfiguration.existing({
    this.detectLongTasks = true,
    this.longTaskThreshold = 0.1,
    this.tracingSamplingRate = 20.0,
    this.reportFlutterPerformance = false,
  })  : applicationId = '<unknown>',
        sessionSamplingRate = 100.0,
        vitalUpdateFrequency = VitalsFrequency.average;

  Map<String, Object?> encode() {
    return {
      'applicationId': applicationId,
      'sampleRate': sessionSamplingRate,
      'detectLongTasks': detectLongTasks,
      'longTaskThreshold': longTaskThreshold,
      'vitalsFrequency': vitalUpdateFrequency.toString(),
      'reportFlutterPerformance': reportFlutterPerformance,
      'customEndpoint': customEndpoint,
      'attachViewEventMapper': rumViewEventMapper != null,
      'attachActionEventMapper': rumActionEventMapper != null,
      'attachResourceEventMapper': rumResourceEventMapper != null,
      'attachErrorEventMapper': rumErrorEventMapper != null,
      'attachLongTaskEventMapper': rumLongTaskEventMapper != null,
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

  /// Sets the current version number of the application.
  ///
  /// By default, both iOS and Android sync their version numbers with the
  /// current version in your pubspec, minus any build or pre-release
  /// information. This property should only be used if you want to add this
  /// additional information back in, or if the version in your pubspec does not
  /// match your application version.
  ///
  /// Because 'version' is a Datadog tag, it needs to comply with the rules in
  /// [Defining
  /// Tags](https://docs.datadoghq.com/getting_started/tagging/#defining-tags)
  /// Datadog documentation. We will automatically replace `+` with `-` for
  /// simplicity.
  ///
  /// Note: If you are uploading Flutter symbols or an Android mapping file,
  /// this version MUST match the version specified in the `flutter-symbols
  /// upload` command in order for symbolication to work.
  String? version;

  /// Get the defined version as a Datadog compliant tag.
  ///
  /// Because 'version' is a Datadog tag, it needs to comply with the rules in
  /// [Defining
  /// Tags](https://docs.datadoghq.com/getting_started/tagging/#defining-tags)
  /// Datadog documentation. This returns your supplied version with on that
  /// automatically replaces `+` with `-`.
  String? get versionTag => version?.replaceAll('+', '-');

  /// Set the current flavor (variant) of the application
  ///
  /// This must match the flavor set during symbol upload in order for stack
  /// trace deobfuscation to work. By default, the flavor parameter is null and
  /// will not appear as a tag in RUM, but other tools will default to 'release'
  String? flavor;

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

  /// A list of first party hosts, used in conjunction with Datadog network
  /// tracking packages like `datadog_tracking_http_client`.
  ///
  /// This also sets all specified hosts to send Datadog tracing headers.
  ///
  /// For more information, see [firstPartyHostsWithTracingHeaders].
  ///
  /// Note: using this method will override any value set in
  /// [firstPartHostsWithTracingHeaders]. If you need to specify different
  /// headers per host, use that property instead.
  List<String> get firstPartyHosts =>
      firstPartyHostsWithTracingHeaders.keys.toList();
  set firstPartyHosts(List<String> hosts) {
    firstPartyHostsWithTracingHeaders.clear();
    for (var entry in hosts) {
      firstPartyHostsWithTracingHeaders[entry] = {TracingHeaderType.datadog};
    }
  }

  /// A list of first party hosts and the types of tracing headers Datadog
  /// should automatically inject on resource calls. This is used in conjunction
  /// with Datadog network tracking packages like `datadog_tracking_http_client`
  ///
  /// For more information about tracing headers, see [TracingHeaderType].
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
  Map<String, Set<TracingHeaderType>> firstPartyHostsWithTracingHeaders = {};

  /// Configuration for the logging feature. If this configuration is null,
  /// logging is disabled.
  LoggingConfiguration? loggingConfiguration;

  /// A function that allows you to modify or drop specific [LogEvent]s
  /// before they are sent to Datadog.
  LogEventMapper? logEventMapper;

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
    this.version,
    this.flavor,
    this.customEndpoint,
    this.telemetrySampleRate,
    List<String>? firstPartyHosts,
    this.firstPartyHostsWithTracingHeaders = const {},
    this.loggingConfiguration,
    this.logEventMapper,
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

    // Attempt a union if both configuration options are present
    if (firstPartyHosts != null) {
      // make map mutable in case it's the default
      firstPartyHostsWithTracingHeaders =
          Map<String, Set<TracingHeaderType>>.from(
              firstPartyHostsWithTracingHeaders);

      for (var entry in firstPartyHosts) {
        final headerTypes = firstPartyHostsWithTracingHeaders[entry];
        if (headerTypes == null) {
          firstPartyHostsWithTracingHeaders[entry] = {
            TracingHeaderType.datadog
          };
        } else {
          headerTypes.add(TracingHeaderType.datadog);
        }
      }
    }
  }

  void addPlugin(DatadogPluginConfiguration pluginConfiguration) =>
      additionalPlugins.add(pluginConfiguration);

  Map<String, Object?> encode() {
    // Add version to additional config as part of encoding
    final encodedAdditionalConfig = Map<String, Object?>.from(additionalConfig);
    if (version != null) {
      encodedAdditionalConfig[DatadogConfigKey.version] = versionTag;
    }

    if (flavor != null) {
      encodedAdditionalConfig[DatadogConfigKey.variant] = flavor;
    }

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
      'additionalConfig': encodedAdditionalConfig,
      'attachLogMapper': logEventMapper != null,
      'customLogsEndpoint': customLogsEndpoint,
    };
  }
}

/// Configuration options used when attaching to an existing instance of a
/// DatadogSdk.
class DdSdkExistingConfiguration {
  /// The configuration to use for the default global logger
  ///
  /// Passing a configuration to [logConfiguration] will create a default global
  /// log with the given parameters and assign it to [DatadogSdk.logs]. If
  /// logging is not enabled in the Native SDK, this log creation will quietly
  /// fail.
  LoggingConfiguration? loggingConfiguration;

  /// Enable or disable detection of "long tasks"
  ///
  /// Long task detection attempts to detect when an application is doing too
  /// much work on the main isolate which could prevent your app from rendering
  /// at a smooth framerate.
  ///
  /// This option does not have any affect on options already set in the Native
  /// SDK, and only initializes long task detection on the main Dart isolate.
  ///
  /// Defaults to true.
  bool detectLongTasks;

  // The amount of elapsed time that is considered to be a "long task", in /
  //seconds.
  ///
  /// If the main isolate takes more than [longTaskThreshold] seconds to process
  /// a microtask, it will appear as a Long Task in Datadog RUM Explorer. This /
  //has a minimum of 0.02 seconds.
  ///
  /// This threshold only applies to the Dart long task detector. The Native
  //SDKs / will retain their own thresholds.
  ///
  /// Defaults to 0.1 seconds
  final double longTaskThreshold;

  /// A list of first party hosts, used in conjunction with Datadog network
  /// tracking packages like `datadog_tracking_http_client`
  ///
  /// This property only affects network requests made from Flutter, and is not
  /// shared with or populated from existing the SDK.
  ///
  /// See [DdSdkConfiguration.firstPartyHosts] for more information
  List<String> firstPartyHosts = [];

  /// A list of first party hosts and the types of tracing headers Datadog
  /// should automatically inject on resource calls. This is used in conjunction
  /// with Datadog network tracking packages like `datadog_tracking_http_client`
  ///
  /// This property only affects network requests made from Flutter, and is not
  /// shared with or populated from existing the SDK.
  ///
  /// See [DdSdkConfiguration.firstPartyHostsWithTracingHeaders] for more information
  Map<String, Set<TracingHeaderType>> firstPartyHostsWithTracingHeaders = {};

  /// Sets the sampling rate for tracing
  ///
  /// The sampling rate must be a value between `0.0` and `100.0`. A value of
  /// `0.0` means no resources will include APM tracing, `100.0` resource will
  /// include APM tracing
  ///
  /// Similarly to [firstPartyHosts], this property only affects network
  /// requests made from Flutter, and it is not shared or populated from the
  /// existing SDK.
  ///
  /// Defaults to `20.0`.
  double tracingSamplingRate;

  /// Configurations for additional plugins that will be created after Datadog
  /// is initialized.
  final List<DatadogPluginConfiguration> additionalPlugins = [];

  DdSdkExistingConfiguration({
    this.loggingConfiguration,
    this.detectLongTasks = true,
    this.longTaskThreshold = 0.1,
    this.tracingSamplingRate = 20.0,
    List<String>? firstPartyHosts,
    this.firstPartyHostsWithTracingHeaders = const {},
  }) {
    // Attempt a union if both configuration options are present
    if (firstPartyHosts != null) {
      // make map mutable
      firstPartyHostsWithTracingHeaders =
          Map<String, Set<TracingHeaderType>>.from(
              firstPartyHostsWithTracingHeaders);

      for (var entry in firstPartyHosts) {
        final headerTypes = firstPartyHostsWithTracingHeaders[entry];
        if (headerTypes == null) {
          firstPartyHostsWithTracingHeaders[entry] = {
            TracingHeaderType.datadog
          };
        } else {
          headerTypes.add(TracingHeaderType.datadog);
        }
      }
    }
  }

  void addPlugin(DatadogPluginConfiguration pluginConfiguration) =>
      additionalPlugins.add(pluginConfiguration);
}
