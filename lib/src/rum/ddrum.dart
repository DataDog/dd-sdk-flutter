// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'dart:io';

import 'package:flutter/material.dart';

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

class DdRum {
  static DdRumPlatform get _platform {
    return DdRumPlatform.instance;
  }

  final InternalLogger logger;

  DdRum(this.logger);

  /// Notifies that the View identified by [key] starts being presented to the
  /// user. This view will show as [name] in the RUM explorer, and defaults to
  /// [key] if it is not provided. You can also attach custom [attributes],
  /// who's values must be supported by [StandardMessageCodec].
  ///
  /// The [key] passed here must match the [key] passed to [stopView] later.
  Future<void> startView(String key,
      [String? name, Map<String, dynamic> attributes = const {}]) {
    name ??= key;
    return wrap('rum.startView', logger, () {
      return _platform.startView(key, name!, attributes);
    });
  }

  /// Notifies that the View identified by [key] stops being presented to the
  /// user. You can also attach custom [attributes], who's values must be
  /// supported by [StandardMessageCodec].
  ///
  /// The [key] passed here must match the [key] passed to [startView].
  Future<void> stopView(String key,
      [Map<String, dynamic> attributes = const {}]) {
    return wrap('rum.stopView', logger, () {
      return _platform.stopView(key, attributes);
    });
  }

  /// Adds a specific timing named [name] in the currently presented View. The
  /// timing duration will be computed as the number of nanoseconds between the
  /// time the View was started and the time the timing was added.
  Future<void> addTiming(String name) {
    return wrap('rum.addTiming', logger, () {
      return _platform.addTiming(name);
    });
  }

  /// Notifies that the Exception or Error [error] occurred in currently
  /// presented View, with an origin of [source]. You can optionally set
  /// additional [attributes] for this error
  Future<void> addError(Object error, RumErrorSource source,
      {StackTrace? stackTrace, Map<String, dynamic> attributes = const {}}) {
    return wrap('rum.addError', logger, () {
      return _platform.addError(error, source, stackTrace, {
        DatadogPlatformAttributeKey.errorSourceType: 'flutter',
        ...attributes
      });
    });
  }

  /// Notifies that an error occurred in currently presented View, with the
  /// supplied [message] and with an origin of [source]. You can optionally
  /// supply a [stackTrace] and send additional [attributes] for this error
  Future<void> addErrorInfo(String message, RumErrorSource source,
      {StackTrace? stackTrace, Map<String, dynamic> attributes = const {}}) {
    return wrap('rum.addErrorInfo', logger, () {
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
  Future<void> handleFlutterError(FlutterErrorDetails details) {
    return addErrorInfo(
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
  Future<void> startResourceLoading(
      String key, RumHttpMethod httpMethod, String url,
      [Map<String, dynamic> attributes = const {}]) {
    return wrap('rum.startResourceLoading', logger, () {
      return _platform.startResourceLoading(key, httpMethod, url, attributes);
    });
  }

  /// Notifies that the Resource identified by [key] stopped being loaded
  /// successfully and supplies additional information about the Resource loaded,
  /// including its [kind], the [statusCode] of the response, the [size] of the
  /// Resource, and any other custom [attributes] to attach to the resource.
  Future<void> stopResourceLoading(
      String key, int? statusCode, RumResourceType kind,
      [int? size, Map<String, dynamic> attributes = const {}]) {
    return wrap('rum.stopResourceLoading', logger, () {
      return _platform.stopResourceLoading(
          key, statusCode, kind, size, attributes);
    });
  }

  /// Notifies that the Resource identified by [key] stopped being loaded with an
  /// Exception specified by [error]. You can optionally supply custom
  /// [attributes] to attach to this Resource.
  Future<void> stopResourceLoadingWithError(String key, Exception error,
      [Map<String, dynamic> attributes = const {}]) {
    return wrap('rum.stopResourceLoadingWithError', logger, () {
      return _platform.stopResourceLoadingWithError(key, error, attributes);
    });
  }

  /// Notifies that the Resource identified by [key] stopped being loaded with
  /// the supplied [message]. You can optionally supply custom [attributes] to
  /// attach to this Resource.
  Future<void> stopResourceLoadingWithErrorInfo(String key, String message,
      [Map<String, dynamic> attributes = const {}]) {
    return wrap('rum.stopResourceLoadingWithErrorInfo', logger, () {
      return _platform.stopResourceLoadingWithErrorInfo(
          key, message, attributes);
    });
  }

  /// Register the occurrence of a User Action.
  ///
  /// This is used to a track discrete User Actions (e.g. "tap") specified by
  /// [type]. The [name] and [attributes] supplied will be associated with this
  /// user action.
  Future<void> addUserAction(RumUserActionType type, String name,
      [Map<String, dynamic> attributes = const {}]) {
    return wrap('rum.addUserAction', logger, () {
      return _platform.addUserAction(type, name, attributes);
    });
  }

  /// Notifies that a User Action of [type] has started, named [name]. This is
  /// used to track long running user actions (e.g. "scroll"). Such an User
  /// Action must be stopped with [stopUserAction], and will be stopped
  /// automatically if it lasts for more than 10 seconds. You can optionally
  /// provide custom [attributes].
  Future<void> startUserAction(RumUserActionType type, String name,
      [Map<String, dynamic> attributes = const {}]) {
    return wrap('rum.startUserAction', logger, () {
      return _platform.startUserAction(type, name, attributes);
    });
  }

  /// Notifies that the User Action of [type], named [name] has stopped.
  /// This is used to stop tracking long running user actions (e.g. "scroll"),
  /// started with [startUserAction].
  Future<void> stopUserAction(RumUserActionType type, String name,
      [Map<String, dynamic> attributes = const {}]) {
    return wrap('rum.stopUserAction', logger, () {
      return _platform.stopUserAction(type, name, attributes);
    });
  }

  /// Adds a custom attribute with [key] and [value] to all future events sent
  /// by the RUM monitor. Note that [value] must be supported by
  /// [StandardMessageCodec].
  Future<void> addAttribute(String key, dynamic value) {
    return wrap('rum.addAttributes', logger, () {
      return _platform.addAttribute(key, value);
    });
  }

  /// Removes the custom attribute [key] from all future events sent by the RUM
  /// monitor. Events created prior to this call will not lose this attribute.
  Future<void> removeAttribute(String key) {
    return wrap('rum.removeAttribute', logger, () {
      return _platform.removeAttribute(key);
    });
  }
}
