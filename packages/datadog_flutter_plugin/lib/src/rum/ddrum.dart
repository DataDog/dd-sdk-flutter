// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

import '../../datadog_flutter_plugin.dart';
import '../../datadog_internal.dart';
import 'ddrum_platform_interface.dart';
import 'rum_long_task_observer.dart';

/// HTTP method of the resource
enum RumHttpMethod { post, get, head, put, delete, patch }

RumHttpMethod rumMethodFromMethodString(String value) {
  var lowerValue = value.toLowerCase();
  return RumHttpMethod.values
      .firstWhere((e) => e.toString() == 'RumHttpMethod.$lowerValue');
}

/// Describes the type of a RUM Action.
enum RumActionType { tap, scroll, swipe, custom }

/// Describe the source of a RUM Error.
enum RumErrorSource {
  /// Error originated in the source code.
  source,

  /// Error originated in the network layer.
  network,

  /// Error originated in a webview.
  webview,

  /// Error originated in a web console (used by bridges).
  console,

  /// Custom error source.
  custom,
}

/// Describe the type of resource loaded.
enum RumResourceType {
  document,
  image,
  xhr,
  beacon,
  css,
  fetch,
  font,
  js,
  media,
  other,
  native
}

RumResourceType resourceTypeFromContentType(ContentType? type) {
  if (type == null) {
    return RumResourceType.native;
  }

  switch (type.primaryType) {
    case 'image':
      return RumResourceType.image;
    case 'audio':
    case 'video':
      return RumResourceType.media;
    case 'font':
      return RumResourceType.font;
  }
  switch (type.subType) {
    case 'javascript':
      return RumResourceType.js;
    case 'css':
      return RumResourceType.css;
  }
  return RumResourceType.native;
}

class DatadogRum {
  static DdRumPlatform get _platform {
    return DdRumPlatform.instance;
  }

  final sampleRandom = Random();

  final DatadogRumConfiguration configuration;
  final InternalLogger logger;

  RumLongTaskObserver? _longTaskObserver;

  static Future<DatadogRum?> enable(
      DatadogSdk core, DatadogRumConfiguration configuration) async {
    DatadogRum? rum;
    await wrapAsync('rum.enable', core.internalLogger, null, () {
      DdRumPlatform.instance.enable(configuration);
      rum = DatadogRum._(configuration, core.internalLogger);

      core.updateConfigurationInfo(
          LateConfigurationProperty.trackFlutterPerformance,
          configuration.reportFlutterPerformance);
      core.updateConfigurationInfo(
          LateConfigurationProperty.trackCrossPlatformLongTasks,
          configuration.detectLongTasks);
    });

    return rum;
  }

  DatadogRum._(this.configuration, this.logger) {
    // Never use long task observer on web -- the Browser SDK should
    // capture stalls on the main thread automatically.
    if (!kIsWeb && configuration.detectLongTasks) {
      _longTaskObserver = RumLongTaskObserver(
        longTaskThreshold: configuration.longTaskThreshold,
        rumInstance: this,
      );
      _longTaskObserver!.init();
    }
    if (configuration.reportFlutterPerformance) {
      ambiguate(SchedulerBinding.instance)
          ?.addTimingsCallback(_timingsCallback);
    }
  }

  /// The sampling rate for tracing resources.
  ///
  /// See [RumConfiguration.tracingSamplingRate]
  double get tracingSamplingRate => configuration.tracingSamplingRate;

  /// Notifies that the View identified by [key] starts being presented to the
  /// user. This view will show as [name] in the RUM explorer, and defaults to
  /// [key] if it is not provided. You can also attach custom [attributes],
  /// who's values must be supported by [StandardMessageCodec].
  ///
  /// The [key] passed here must match the [key] passed to [stopView] later.
  void startView(String key,
      [String? name, Map<String, Object?> attributes = const {}]) {
    name ??= key;
    wrap('rum.startView', logger, attributes, () {
      return _platform.startView(key, name!, attributes);
    });
  }

  /// Notifies that the View identified by [key] stops being presented to the
  /// user. You can also attach custom [attributes], who's values must be
  /// supported by [StandardMessageCodec].
  ///
  /// The [key] passed here must match the [key] passed to [startView].
  void stopView(String key, [Map<String, Object?> attributes = const {}]) {
    wrap('rum.stopView', logger, attributes, () {
      return _platform.stopView(key, attributes);
    });
  }

  /// Adds a specific timing named [name] in the currently presented View. The
  /// timing duration will be computed as the number of nanoseconds between the
  /// time the View was started and the time the timing was added.
  void addTiming(String name) {
    wrap('rum.addTiming', logger, null, () {
      return _platform.addTiming(name);
    });
  }

  /// Notifies that the Exception or Error [error] occurred in currently
  /// presented View, with an origin of [source]. You can optionally set
  /// additional [attributes] for this error, an [errorType] and a
  /// [stackTrace]
  void addError(
    Object error,
    RumErrorSource source, {
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes = const {},
  }) {
    wrap('rum.addError', logger, attributes, () {
      return _platform.addError(error, source, stackTrace, errorType, {
        DatadogPlatformAttributeKey.errorSourceType: 'flutter',
        ...attributes
      });
    });
  }

  /// Notifies that an error occurred in currently presented View, with the
  /// supplied [message] and with an origin of [source]. You can optionally
  /// supply a [stackTrace], [errorType], and send additional [attributes] for
  /// this error
  void addErrorInfo(
    String message,
    RumErrorSource source, {
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes = const {},
  }) {
    wrap('rum.addErrorInfo', logger, attributes, () {
      return _platform.addErrorInfo(message, source, stackTrace, errorType, {
        DatadogPlatformAttributeKey.errorSourceType: 'flutter',
        ...attributes
      });
    });
  }

  /// Send a Flutter error to RUM. This is used in conjunction with
  /// FlutterError.onError by doing the following during initialization
  ///
  /// ```dart
  /// FlutterError.onError = (FlutterErrorDetails details) {
  ///    FlutterError.presentError(details);
  ///    DatadogSdk.instance.rum?.handleFlutterError(details);
  /// };
  /// ```
  void handleFlutterError(FlutterErrorDetails details) {
    addErrorInfo(
      details.exceptionAsString(),
      RumErrorSource.source,
      stackTrace: details.stack,
      attributes: {'flutter_error_reason': details.context?.toString()},
    );
  }

  /// Notifies that the a Resource identified by [key] started being loaded from
  /// given [url] using the specified [httpMethod]. The supplied custom
  /// [attributes] will be attached to this Resource.
  ///
  /// Note that [key] must be unique among all Resources being currently loaded,
  /// and should be sent to [stopResource] or
  /// [stopResourceWithError] / [stopResourceWithErrorInfo] when
  /// resource loading is complete.
  void startResource(String key, RumHttpMethod httpMethod, String url,
      [Map<String, Object?> attributes = const {}]) {
    wrap('rum.startResource', logger, attributes, () {
      return _platform.startResource(key, httpMethod, url, attributes);
    });
  }

  /// Notifies that the Resource identified by [key] stopped being loaded
  /// successfully and supplies additional information about the Resource loaded,
  /// including its [kind], the [statusCode] of the response, the [size] of the
  /// Resource, and any other custom [attributes] to attach to the resource.
  void stopResource(String key, int? statusCode, RumResourceType kind,
      [int? size, Map<String, Object?> attributes = const {}]) {
    wrap('rum.stopResource', logger, attributes, () {
      return _platform.stopResource(key, statusCode, kind, size, attributes);
    });
  }

  /// Notifies that the Resource identified by [key] stopped being loaded with an
  /// Exception specified by [error]. You can optionally supply custom
  /// [attributes] to attach to this Resource.
  void stopResourceWithError(String key, Exception error,
      [Map<String, Object?> attributes = const {}]) {
    wrap('rum.stopResourceWithError', logger, attributes, () {
      return _platform.stopResourceWithError(key, error, attributes);
    });
  }

  /// Notifies that the Resource identified by [key] stopped being loaded with
  /// the supplied [message]. You can optionally supply custom [attributes] to
  /// attach to this Resource.
  void stopResourceWithErrorInfo(String key, String message, String type,
      [Map<String, Object?> attributes = const {}]) {
    wrap('rum.stopResourceWithErrorInfo', logger, attributes, () {
      return _platform.stopResourceWithErrorInfo(
          key, message, type, attributes);
    });
  }

  /// Register the occurrence of a User Action.
  ///
  /// This is used to a track discrete User Actions (e.g. "tap") specified by
  /// [type]. The [name] and [attributes] supplied will be associated with this
  /// user action.
  void addAction(RumActionType type, String name,
      [Map<String, Object?> attributes = const {}]) {
    wrap('rum.addAction', logger, attributes, () {
      return _platform.addAction(type, name, attributes);
    });
  }

  /// Notifies that a User Action of [type] has started, named [name]. This is
  /// used to track long running user actions (e.g. "scroll"). Such an User
  /// Action must be stopped with [stopUserAction], and will be stopped
  /// automatically if it lasts for more than 10 seconds. You can optionally
  /// provide custom [attributes].
  void startAction(RumActionType type, String name,
      [Map<String, Object?> attributes = const {}]) {
    wrap('rum.startAction', logger, attributes, () {
      return _platform.startAction(type, name, attributes);
    });
  }

  /// Notifies that the User Action of [type], named [name] has stopped.
  /// This is used to stop tracking long running user actions (e.g. "scroll"),
  /// started with [startUserAction].
  void stopAction(RumActionType type, String name,
      [Map<String, Object?> attributes = const {}]) {
    wrap('rum.stopAction', logger, attributes, () {
      return _platform.stopAction(type, name, attributes);
    });
  }

  /// Adds a custom attribute with [key] and [value] to all future events sent
  /// by the RUM monitor. Note that [value] must be supported by
  /// [StandardMessageCodec].
  void addAttribute(String key, dynamic value) {
    wrap('rum.addAttributes', logger, {'value': value}, () {
      return _platform.addAttribute(key, value);
    });
  }

  /// Removes the custom attribute [key] from all future events sent by the RUM
  /// monitor. Events created prior to this call will not lose this attribute.
  void removeAttribute(String key) {
    wrap('rum.removeAttribute', logger, null, () {
      return _platform.removeAttribute(key);
    });
  }

  /// Adds the result of evaluating a feature flag with a given [name] and
  /// [value] to the view. Feature flag evaluations are local to the active view
  /// and are cleared when the view is stopped
  void addFeatureFlagEvaluation(String name, Object value) {
    wrap('rum.addFeatureFlagEvaluation', logger, null, () {
      return _platform.addFeatureFlagEvaluation(name, value);
    });
  }

  /// Stops the current session. A new session will start in response to a call
  /// to [startView], [addUserAction], or [startUserAction]. If the session is
  /// started because of a call to [addUserAction] or [startUserAction], the
  /// last know view is restarted in the new session.
  void stopSession() {
    wrap('rum.stopSession', logger, null, () {
      return _platform.stopSession();
    });
  }

  /// Uses the configured [RumConfiguration.tracingSamplingRate] to determine if
  /// a sample should be traced.
  ///
  /// This is used by Datadog tracing plugins like `datadog_tracing_http_client`
  /// to add the proper headers to network requests.
  bool shouldSampleTrace() {
    return (sampleRandom.nextDouble() * 100) <
        configuration.tracingSamplingRate;
  }

  @internal
  void reportLongTask(int taskLengthMs) {
    wrap('rum.reportLongTask', logger, null, () {
      return _platform.reportLongTask(DateTime.now(), taskLengthMs);
    });
  }

  void _timingsCallback(List<FrameTiming> timings) {
    if (timings.isNotEmpty) {
      var buildTimes = <double>[];
      var rasterTimes = <double>[];
      for (final timing in timings) {
        buildTimes.add(timing.buildDuration.inMicroseconds /
            Duration.microsecondsPerSecond);
        rasterTimes.add(timing.rasterDuration.inMicroseconds /
            Duration.microsecondsPerSecond);
      }

      wrap('rum.updatePerformanceMetrics', logger, null, () {
        return _platform.updatePerformanceMetrics(buildTimes, rasterTimes);
      });
    }
  }
}
