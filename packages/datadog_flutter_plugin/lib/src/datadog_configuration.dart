// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import '../datadog_flutter_plugin.dart';
import '../datadog_internal.dart';

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

/// Defines the maximum amount of batches processed sequentially without a delay
/// within one reading/uploading cycle. [high] means that more data will
/// be sent in a single upload cycle but more CPU and memory will be used to
/// process the data. [low] means that less data will be sent in a
/// single upload cycle but less CPU and memory will be used to process the
/// data.
enum BatchProcessingLevel {
  /// Prefer less processing with smaller batches, but less CPU and memory usage
  low,

  /// Medium batch processing. This is the default.
  medium,

  /// Prefer higher processing sending larger batches, but more CPU and memory usage
  high,
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

  /// Asia based servers. Sends data to
  /// [ap1.datadoghq.com](https://ap1.datadoghq.com).
  ap1,
}

/// Defines whether the trace context should be injected into all requests or
/// only into requests that are sampled in.
enum TraceContextInjection {
  /// Injects trace context into all requests regardless of the sampling decision.
  all,

  /// Injects trace context only into sampled requests.
  sampled,
}

class DatadogConfiguration {
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

  /// The service name for this application
  String? service;

  /// Sets the preferred size of batched data uploaded to Datadog servers. This
  /// value impacts the size and number of requests performed by the SDK.
  BatchSize? batchSize;

  /// Sets the preferred frequency of uploading data to Datadog servers. This
  /// value impacts the frequency of performing network requests by the SDK.
  UploadFrequency? uploadFrequency;

  /// Sets the level of batch processing
  BatchProcessingLevel? batchProcessingLevel;

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
  /// Datadog documentation. This returns your supplied version that
  /// automatically replaces `+` with `-`.
  String? get versionTag => version?.replaceAll('+', '-');

  /// Set the current flavor (variant) of the application
  ///
  /// This must match the flavor set during symbol upload in order for stack
  /// trace deobfuscation to work. By default, the flavor parameter is null and
  /// will not appear as a tag in RUM, but other tools will default to 'release'
  String? flavor;

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
      firstPartyHostsWithTracingHeaders[entry] = {
        TracingHeaderType.datadog,
        TracingHeaderType.tracecontext
      };
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

  /// Any additional configuration to be passed to the native SDKs
  final Map<String, Object?> additionalConfig = {};

  /// Configurations for additional plugins that will be created after Datadog
  /// is initialized.
  final List<DatadogPluginConfiguration> additionalPlugins = [];

  DatadogLoggingConfiguration? loggingConfiguration;
  DatadogRumConfiguration? rumConfiguration;

  DatadogConfiguration({
    required this.clientToken,
    required this.env,
    required this.site,
    this.nativeCrashReportEnabled = false,
    this.service,
    this.uploadFrequency,
    this.batchSize,
    this.batchProcessingLevel,
    this.version,
    this.flavor,
    List<String>? firstPartyHosts,
    this.firstPartyHostsWithTracingHeaders = const {},
    this.loggingConfiguration,
    this.rumConfiguration,
  }) {
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
            TracingHeaderType.datadog,
            TracingHeaderType.tracecontext,
          };
        } else {
          headerTypes.add(TracingHeaderType.datadog);
          headerTypes.add(TracingHeaderType.tracecontext);
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
      'site': site.toString(),
      'nativeCrashReportEnabled': nativeCrashReportEnabled,
      'service': service,
      'batchSize': batchSize?.toString(),
      'uploadFrequency': uploadFrequency?.toString(),
      'batchProcessingLevel': batchProcessingLevel?.toString(),
      'additionalConfig': encodedAdditionalConfig,
    };
  }
}

/// Configuration options used when attaching to an existing instance of a
/// DatadogSdk.
class DatadogAttachConfiguration {
  /// Enable or disable detection of "long tasks"
  ///
  /// Long task detection attempts to detect when an application is doing too
  /// much work on the main isolate which could prevent your app from rendering
  /// at a smooth framerate.
  ///
  /// This option does not have any affect on options already set in the Native
  /// SDK, and only initializes long task detection on the main Dart isolate.
  ///
  /// This option is ignored if RUM is not enabled in the Native SDK.
  ///
  /// Defaults to true.
  bool detectLongTasks;

  // The amount of elapsed time that is considered to be a "long task", in /
  //seconds.
  ///
  /// If the main isolate takes more than [longTaskThreshold] seconds to process
  /// a microtask, it will appear as a Long Task in Datadog RUM Explorer. This
  /// has a minimum of 0.02 seconds.
  ///
  /// This threshold only applies to the Dart long task detector. The Native
  /// SDKs / will retain their own thresholds.
  ///
  /// This option is ignored if RUM is not enabled in the Native SDK.
  ///
  /// Defaults to 0.1 seconds
  final double longTaskThreshold;

  /// Whether to report Flutter specific performance metrics (build and raster
  /// times)
  ///
  /// This uses the [SchedulerBinding.addTimingsCallback] method to report build
  /// and raster times for views, and has a documented negligible impact on
  /// performance.
  ///
  /// Defaults to false
  bool reportFlutterPerformance = false;

  /// A list of first party hosts, used in conjunction with Datadog network
  /// tracking packages like `datadog_tracking_http_client`
  ///
  /// This property only affects network requests made from Flutter, and is not
  /// shared with or populated from existing the SDK.
  ///
  /// Overwriting this property will overwrite
  /// [DatadogAttachConfiguration.firstPartyHostsWithTracingHeaders]
  ///
  /// See [DatadogConfiguration.firstPartyHosts] for more information
  List<String> get firstPartyHosts =>
      firstPartyHostsWithTracingHeaders.keys.toList();
  set firstPartyHosts(List<String> hosts) {
    firstPartyHostsWithTracingHeaders.clear();
    for (var entry in hosts) {
      firstPartyHostsWithTracingHeaders[entry] = {
        TracingHeaderType.datadog,
        TracingHeaderType.tracecontext
      };
    }
  }

  /// A list of first party hosts and the types of tracing headers Datadog
  /// should automatically inject on resource calls. This is used in conjunction
  /// with Datadog network tracking packages like `datadog_tracking_http_client`
  ///
  /// This property only affects network requests made from Flutter, and is not
  /// shared with or populated from existing the SDK.
  ///
  /// See [DatadogConfiguration.firstPartyHostsWithTracingHeaders] for more information
  Map<String, Set<TracingHeaderType>> firstPartyHostsWithTracingHeaders = {};

  /// Sets the sampling rate for tracing
  ///
  /// The sampling rate must be a value between `0.0` and `100.0`. A value of
  /// `0.0` means no resources will include APM tracing, while a value of `100.0`
  /// means all resources will include APM tracing
  ///
  /// This property only affects network requests made from Flutter, and it is
  /// not shared or populated from the existing SDK.
  ///
  /// Defaults to `20.0`.
  double traceSampleRate;

  /// The strategy for injecting trace context into requests. See [TraceContextInjection].
  ///
  /// Defaults to [TraceContextInjection.all].
  TraceContextInjection traceContextInjection = TraceContextInjection.all;

  /// Configurations for additional plugins that will be created after Datadog
  /// is initialized.
  final List<DatadogPluginConfiguration> additionalPlugins = [];

  DatadogAttachConfiguration({
    this.detectLongTasks = true,
    this.longTaskThreshold = 0.1,
    this.traceSampleRate = 20.0,
    this.reportFlutterPerformance = false,
    List<String>? firstPartyHosts,
    this.firstPartyHostsWithTracingHeaders = const {},
    this.traceContextInjection = TraceContextInjection.all,
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
            TracingHeaderType.datadog,
            TracingHeaderType.tracecontext
          };
        } else {
          headerTypes.add(TracingHeaderType.datadog);
          headerTypes.add(TracingHeaderType.tracecontext);
        }
      }
    }
  }

  void addPlugin(DatadogPluginConfiguration pluginConfiguration) =>
      additionalPlugins.add(pluginConfiguration);
}
