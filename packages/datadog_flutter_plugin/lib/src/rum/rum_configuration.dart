// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:math';

import '../../datadog_flutter_plugin.dart';

/// Defines the frequency at which Datadog SDK will collect mobile vitals, such
/// as CPU and memory usage.
enum VitalsFrequency {
  /// Collect mobile vitals every 100ms.
  frequent,

  /// Collect mobile vitals every 500ms.
  average,

  /// Collect mobile vitals every 1000ms.
  rare
}

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

/// Configuration options for the Datadog Real User Monitoring (RUM) feature.
class DatadogRumConfiguration {
  // Either a RUM Application Id. Obtained on the Datadog website.
  String applicationId;

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
  double traceSampleRate;

  /// The strategy for injecting trace context into requests. See [TraceContextInjection].
  ///
  /// Defaults to [TraceContextInjection.all].
  TraceContextInjection traceContextInjection = TraceContextInjection.all;

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

  bool trackFrustrations;

  /// Sets the preferred frequency for collecting mobile vitals.
  ///
  /// Note this setting does not affect the sampling done by [reportFlutterPerformance].
  /// Assign to `null` to disable mobile vitals collection.
  ///
  /// Defaults to [VitalsFrequency.average].
  VitalsFrequency? vitalUpdateFrequency;

  /// Whether to report Flutter specific performance metrics (build and raster
  /// times)
  ///
  /// This uses the [SchedulerBinding.addTimingsCallback] method to report build
  /// and raster times for views, and has a documented negligible impact on
  /// performance.
  ///
  /// Defaults to false
  bool reportFlutterPerformance = false;

  /// Whether to track non-fatal ANRs (Application Not Responding) errors as RUM
  /// errors.
  ///
  /// This option is specific to Android.
  ///
  /// By default, the reporting of non-fatal ANRs on Android 30+ is disabled
  /// because it would create too much noise over fatal ANRs. On Android 29 and
  /// below, however, the reporting of non-fatal ANRs is enabled by default, as
  /// fatal ANRs cannot be reported on those versions.
  bool? trackNonFatalAnrs;

  /// Set the threshold for reporting for non-fatal app hangs in seconds.
  ///
  /// This options is specific to iOS.
  ///
  /// App hangs are a type of error that occurs when the application is
  /// unresponsive for too long. Set the parameter to the minimal duration you
  /// want app hangs to be reported. For example, enter 0.25 to report hangs
  /// lasting at least 250 milliseconds. See [Configure the app hang
  /// threshold](https://docs.datadoghq.com/real_user_monitoring/error_tracking/mobile/ios/?tab=cocoapods#configure-the-app-hang-threshold)
  /// for more guidance on what to set this value to.
  ///
  /// Defaults to disabled (`null`).
  double? appHangThreshold;

  /// Use a custom endpoint for sending RUM data.
  String? customEndpoint;

  //
  double telemetrySampleRate;

  /// A function that allows you to modify or drop specific [RumViewEvent]s
  /// before they are sent to Datadog.
  RumViewEventMapper? viewEventMapper;

  /// A function that allows you to modify or drop specific [RumActionEvent]s
  /// before they are sent to Datadog.
  RumActionEventMapper? actionEventMapper;

  /// A function that allows you to modify or drop specific [RumResourceEvent]s
  /// before they are sent to Datadog.
  RumResourceEventMapper? resourceEventMapper;

  /// A function that allows you to modify or drop specific [RumResourceEvent]s
  /// before they are sent to Datadog.
  RumErrorEventMapper? errorEventMapper;

  /// A function that allows you to modify or drop specific [RumLongTaskEvent]s
  /// before they are sent to Datadog.
  RumLongTaskEventMapper? longTaskEventMapper;

  Map<String, Object?> additionalConfig;

  DatadogRumConfiguration({
    required this.applicationId,
    double sessionSamplingRate = 100.0,
    double traceSampleRate = 20.0,
    this.traceContextInjection = TraceContextInjection.all,
    this.detectLongTasks = true,
    double longTaskThreshold = 0.1,
    this.trackFrustrations = true,
    this.vitalUpdateFrequency = VitalsFrequency.average,
    this.reportFlutterPerformance = false,
    this.trackNonFatalAnrs,
    this.appHangThreshold,
    this.customEndpoint,
    this.telemetrySampleRate = 20.0,
    this.viewEventMapper,
    this.actionEventMapper,
    this.resourceEventMapper,
    this.errorEventMapper,
    this.longTaskEventMapper,
    this.additionalConfig = const <String, Object>{},
  })  : sessionSamplingRate = max(0, min(sessionSamplingRate, 100)),
        traceSampleRate = max(0, min(traceSampleRate, 100)),
        longTaskThreshold = max(0.02, longTaskThreshold);

  Map<String, Object?> encode() {
    return {
      'applicationId': applicationId,
      'sessionSampleRate': sessionSamplingRate,
      'detectLongTasks': detectLongTasks,
      'longTaskThreshold': longTaskThreshold,
      'trackFrustrations': trackFrustrations,
      'vitalsUpdateFrequency': vitalUpdateFrequency.toString(),
      'reportFlutterPerformance': reportFlutterPerformance,
      'trackNonFatalAnrs': trackNonFatalAnrs,
      'appHangThreshold': appHangThreshold,
      'customEndpoint': customEndpoint,
      'telemetrySampleRate': telemetrySampleRate,
      'attachViewEventMapper': viewEventMapper != null,
      'attachActionEventMapper': actionEventMapper != null,
      'attachResourceEventMapper': resourceEventMapper != null,
      'attachErrorEventMapper': errorEventMapper != null,
      'attachLongTaskEventMapper': longTaskEventMapper != null,
      'additionalConfig': additionalConfig,
    };
  }
}
