// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'ddrum_platform_interface.dart';

/// HTTP method of the resource
enum RumHttpMethod { post, get, head, put, delete, patch }

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

/// Descripbe the type of resource loaded
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

class DdRum {
  static DdRumPlatform get _platform {
    return DdRumPlatform.instance;
  }

  /// Notifies that the View identified by [key] starts being presented to the
  /// user. This view will show as [name] in the RUM explorer, and defaultes to
  /// [key] if it is not provided. You can also attach custom [attributes],
  /// who's values must be supported by [StandardMessageCodec].
  ///
  /// The [key] passed here must match the [key] passed to [stopView] later.
  Future<void> startView(String key,
      [String? name, Map<String, dynamic> attributes = const {}]) {
    name ??= key;
    return _platform.startView(key, name, attributes);
  }

  /// Notifies that the View identified by [key] stops being presented to the
  /// user. You can also attach custom [attributes], who's values must be
  /// supported by [StandardMessageCodec].
  ///
  /// The [key] passed here must match the [key] passed to [startView].
  Future<void> stopView(String key,
      [Map<String, dynamic> attributes = const {}]) {
    return _platform.stopView(key, attributes);
  }

  /// Adds a specific timing named [name] in the currently presented View. The
  /// timing duration will be computed as the number of nanoseconds between the
  /// time the View was started and the time the timing was added.
  Future<void> addTiming(String name) {
    return _platform.addTiming(name);
  }

  Future<void> addError(Exception error, RumErrorSource source,
      [Map<String, dynamic> attributes = const {}]) {
    return _platform.addError(error, source, attributes);
  }

  Future<void> addErrorInfo(String message, RumErrorSource source,
      [StackTrace? stack, Map<String, dynamic> attributes = const {}]) {
    return _platform.addErrorInfo(message, source, stack, attributes);
  }

  /// Notifies that the a Resource identified by [key] started being loaded from
  /// given [url] using the specified [httpMethod]. The supplied custom
  /// [attributes] will be atteched to this Resource.
  ///
  /// Note that [key] must be unique among all Resources being currently loaded,
  /// and should be sent to [stopResourceLoading] or
  /// [stopResourceLoadingWithError] / [stopResourceLoadingWithErrorInfo] when
  /// resource loading is complete.
  Future<void> startResourceLoading(
      String key, RumHttpMethod httpMethod, String url,
      [Map<String, dynamic> attributes = const {}]) {
    return _platform.startResourceLoading(key, httpMethod, url, attributes);
  }

  /// Notifies that the Resource identified by [key] stoped being loaded
  /// succesfully and supplies additional information about the Resoure loaded,
  /// including its [kind], the [statusCode] of the response, the [size] of the
  /// Resource, and any other custom [attributes] to attach to the resource.
  Future<void> stopResourceLoading(
      String key, int? statusCode, RumResourceType kind,
      [int? size, Map<String, dynamic> attributes = const {}]) {
    return _platform.stopResourceLoading(
        key, statusCode, kind, size, attributes);
  }

  /// Notifies that the Resource identified by [key] stoped being loaded with an
  /// Exception specified by [error]. You can optionally supply custom
  /// [attributes] to attach to this Resource
  Future<void> stopResourceLoadingWithError(String key, Exception error,
      [Map<String, dynamic> attributes = const {}]) {
    return _platform.stopResourceLoadingWithError(key, error, attributes);
  }

  /// Notifies that the Resource identified by [key] stoped being loaded with
  /// the supplied [message] You can optionally supply custom [attributes] to
  /// attach to this Resource
  Future<void> stopResourceLoadingWithErrorInfo(String key, String message,
      [Map<String, dynamic> attributes = const {}]) {
    return _platform.stopResourceLoadingWithErrorInfo(key, message, attributes);
  }

  /// Register the occurence of a User Action.
  ///
  /// This is used to a track discrete User Actions (e.g. "tap") specified by
  /// [type]. The [name] and [attributes] supplied will be associated with this
  /// user action
  Future<void> addUserAction(RumUserActionType type, String? name,
      [Map<String, dynamic> attributes = const {}]) {
    return _platform.addUserAction(type, name, attributes);
  }
}
