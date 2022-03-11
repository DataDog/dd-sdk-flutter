// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../datadog_flutter_plugin.dart';
import '../attributes.dart';
import '../helpers.dart';
import '../internal_logger.dart';
import 'ddrum_platform_interface.dart';

/// HTTP method of the resource
enum RumHttpMethod { post, get, head, put, delete, patch, unknown }

RumHttpMethod rumMethodFromMethodString(String value) {
  var lowerValue = value.toLowerCase();
  return RumHttpMethod.values
      .firstWhere((e) => e.toString() == 'RumHttpMethod.$lowerValue');
}

/// Describes the type of a RUM Action.
enum RumUserActionType { tap, scroll, swipe, custom }

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

class _TimingSpan {
  int sampleCount = 0;
  int min = 10000000000000000;
  int max = 0;
  int mean = 0;

  void addSample(int sampleMicroseconds) {
    if (sampleMicroseconds < min) min = sampleMicroseconds;
    if (sampleMicroseconds > max) max = sampleMicroseconds;

    mean = (sampleMicroseconds + (sampleCount * mean)) ~/ (sampleCount + 1);
    sampleCount + 1;
  }

  void reset() {
    sampleCount = 0;
    min = 10000000000000000;
    max = 0;
    mean = 0;
  }

  @override
  String toString() {
    const double microToMs = 1 / (1 * 1000);
    String toMsString(int microseconds) {
      return (microseconds * microToMs).toStringAsFixed(3) + 'ms';
    }

    return 'min: ${toMsString(min)}, max: ${toMsString(max)}, mean: ${toMsString(mean)}';
  }
}

class _ViewTimingInfo {
  final buildTiming = _TimingSpan();
  final rasterTiming = _TimingSpan();

  void reset() {
    buildTiming.reset();
    rasterTiming.reset();
  }

  @override
  String toString() {
    return '  Build: ($buildTiming)\n  Raster: ($rasterTiming)\n';
  }
}

class DdRum {
  static DdRumPlatform get _platform {
    return DdRumPlatform.instance;
  }

  final RumConfiguration config;
  final InternalLogger logger;

  String? _currentRumView;
  // If we are in transition, this is the frame at which we transitioned,
  // and therefore we should consider all frame reports previous to this
  // as part of the previous view.
  int? _transitionFrameNumber;
  final _currentViewTiming = _ViewTimingInfo();

  DdRum(
    this.config,
    this.logger,
  ) {
    if (config.trackFrameTiming) {
      SchedulerBinding.instance?.addTimingsCallback(_reportTimings);
    }
  }

  void _reportTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return; // Nothing to do

    for (final timing in timings) {
      _currentViewTiming.buildTiming
          .addSample(timing.buildDuration.inMicroseconds);
      _currentViewTiming.rasterTiming
          .addSample(timing.rasterDuration.inMicroseconds);
      if (_transitionFrameNumber != null &&
          timing.frameNumber >= _transitionFrameNumber!) {
        print('Finished timing for view:\n$_currentViewTiming');
        _transitionFrameNumber = null;
        _currentViewTiming.reset();
      }
    }
  }

  /// Notifies that the View identified by [key] starts being presented to the
  /// user. This view will show as [name] in the RUM explorer, and defaults to
  /// [key] if it is not provided. You can also attach custom [attributes],
  /// who's values must be supported by [StandardMessageCodec].
  ///
  /// The [key] passed here must match the [key] passed to [stopView] later.
  void startView(String key,
      [String? name, Map<String, dynamic> attributes = const {}]) {
    name ??= key;
    wrap('rum.startView', logger, () {
      _transitionFrameNumber =
          PlatformDispatcher.instance.frameData.frameNumber;
      _currentRumView = key;
      return _platform.startView(key, name!, attributes);
    });
  }

  /// Notifies that the View identified by [key] stops being presented to the
  /// user. You can also attach custom [attributes], who's values must be
  /// supported by [StandardMessageCodec].
  ///
  /// The [key] passed here must match the [key] passed to [startView].
  void stopView(String key, [Map<String, dynamic> attributes = const {}]) {
    wrap('rum.stopView', logger, () {
      if (_currentRumView == key) {
        _currentRumView = null;
      }
      return _platform.stopView(key, attributes);
    });
  }

  /// Adds a specific timing named [name] in the currently presented View. The
  /// timing duration will be computed as the number of nanoseconds between the
  /// time the View was started and the time the timing was added.
  void addTiming(String name) {
    wrap('rum.addTiming', logger, () {
      return _platform.addTiming(name);
    });
  }

  /// Notifies that the Exception or Error [error] occurred in currently
  /// presented View, with an origin of [source]. You can optionally set
  /// additional [attributes] for this error
  void addError(Object error, RumErrorSource source,
      {StackTrace? stackTrace, Map<String, dynamic> attributes = const {}}) {
    wrap('rum.addError', logger, () {
      return _platform.addError(error, source, stackTrace, {
        DatadogPlatformAttributeKey.errorSourceType: 'flutter',
        ...attributes
      });
    });
  }

  /// Notifies that an error occurred in currently presented View, with the
  /// supplied [message] and with an origin of [source]. You can optionally
  /// supply a [stackTrace] and send additional [attributes] for this error
  void addErrorInfo(String message, RumErrorSource source,
      {StackTrace? stackTrace, Map<String, dynamic> attributes = const {}}) {
    wrap('rum.addErrorInfo', logger, () {
      return _platform.addErrorInfo(message, source, stackTrace, {
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
  ///    DatadogSdk.instance..rum?.handleFlutterError(details);
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
  /// and should be sent to [stopResourceLoading] or
  /// [stopResourceLoadingWithError] / [stopResourceLoadingWithErrorInfo] when
  /// resource loading is complete.
  void startResourceLoading(String key, RumHttpMethod httpMethod, String url,
      [Map<String, dynamic> attributes = const {}]) {
    wrap('rum.startResourceLoading', logger, () {
      return _platform.startResourceLoading(key, httpMethod, url, attributes);
    });
  }

  /// Notifies that the Resource identified by [key] stopped being loaded
  /// successfully and supplies additional information about the Resource loaded,
  /// including its [kind], the [statusCode] of the response, the [size] of the
  /// Resource, and any other custom [attributes] to attach to the resource.
  void stopResourceLoading(String key, int? statusCode, RumResourceType kind,
      [int? size, Map<String, dynamic> attributes = const {}]) {
    wrap('rum.stopResourceLoading', logger, () {
      return _platform.stopResourceLoading(
          key, statusCode, kind, size, attributes);
    });
  }

  /// Notifies that the Resource identified by [key] stopped being loaded with an
  /// Exception specified by [error]. You can optionally supply custom
  /// [attributes] to attach to this Resource.
  void stopResourceLoadingWithError(String key, Exception error,
      [Map<String, dynamic> attributes = const {}]) {
    wrap('rum.stopResourceLoadingWithError', logger, () {
      return _platform.stopResourceLoadingWithError(key, error, attributes);
    });
  }

  /// Notifies that the Resource identified by [key] stopped being loaded with
  /// the supplied [message]. You can optionally supply custom [attributes] to
  /// attach to this Resource.
  void stopResourceLoadingWithErrorInfo(String key, String message,
      [Map<String, dynamic> attributes = const {}]) {
    wrap('rum.stopResourceLoadingWithErrorInfo', logger, () {
      return _platform.stopResourceLoadingWithErrorInfo(
          key, message, attributes);
    });
  }

  /// Register the occurrence of a User Action.
  ///
  /// This is used to a track discrete User Actions (e.g. "tap") specified by
  /// [type]. The [name] and [attributes] supplied will be associated with this
  /// user action.
  void addUserAction(RumUserActionType type, String name,
      [Map<String, dynamic> attributes = const {}]) {
    wrap('rum.addUserAction', logger, () {
      return _platform.addUserAction(type, name, attributes);
    });
  }

  /// Notifies that a User Action of [type] has started, named [name]. This is
  /// used to track long running user actions (e.g. "scroll"). Such an User
  /// Action must be stopped with [stopUserAction], and will be stopped
  /// automatically if it lasts for more than 10 seconds. You can optionally
  /// provide custom [attributes].
  void startUserAction(RumUserActionType type, String name,
      [Map<String, dynamic> attributes = const {}]) {
    wrap('rum.startUserAction', logger, () {
      return _platform.startUserAction(type, name, attributes);
    });
  }

  /// Notifies that the User Action of [type], named [name] has stopped.
  /// This is used to stop tracking long running user actions (e.g. "scroll"),
  /// started with [startUserAction].
  void stopUserAction(RumUserActionType type, String name,
      [Map<String, dynamic> attributes = const {}]) {
    wrap('rum.stopUserAction', logger, () {
      return _platform.stopUserAction(type, name, attributes);
    });
  }

  /// Adds a custom attribute with [key] and [value] to all future events sent
  /// by the RUM monitor. Note that [value] must be supported by
  /// [StandardMessageCodec].
  void addAttribute(String key, dynamic value) {
    wrap('rum.addAttributes', logger, () {
      return _platform.addAttribute(key, value);
    });
  }

  /// Removes the custom attribute [key] from all future events sent by the RUM
  /// monitor. Events created prior to this call will not lose this attribute.
  void removeAttribute(String key) {
    wrap('rum.removeAttribute', logger, () {
      return _platform.removeAttribute(key);
    });
  }
}
