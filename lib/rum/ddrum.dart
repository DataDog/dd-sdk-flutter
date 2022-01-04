// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'ddrum_platform_interface.dart';

class DdRum {
  static DdRumPlatform get _platform {
    return DdRumPlatform.instance;
  }

  /// Notifies that the View identified by [key] starts being presented to the
  /// user. This view will show as [name] in the RUM explorer, and defaultes to
  /// [key] if it is not provided. you can also attach custom [attributes],
  /// who's values must be supported by [StandardMessageCodec]
  ///
  /// The [key] passed here must match the [key] passed to [stopView] later
  Future<void> startView(String key,
      [String? name, Map<String, dynamic> attributes = const {}]) {
    name ??= key;
    return _platform.startView(key, name, attributes);
  }

  /// Notifies that the View identified by [key] stops being presented to the
  /// user. You can also attach custom [attributes], who's values must be
  /// supported by [StandardMessageCodec]
  ///
  /// The [key] passed here must match the [key] passed to [startView]
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
}
