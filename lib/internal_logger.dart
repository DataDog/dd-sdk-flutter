// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:flutter/foundation.dart';

import 'datadog_sdk.dart';

/// This class is used internally by the SDK to log issues to the client
/// developers. Note that all logging from the Flutter portions of the SDK are
/// disabled if kDebugMode is not set.
class InternalLogger {
  bool useEmoji = true;
  Verbosity sdkVerbosity = Verbosity.info;

  static const _emojiMap = {
    Verbosity.debug: '🪳',
    Verbosity.info: '🗒',
    Verbosity.warn: '⚠️',
    Verbosity.error: '💥'
  };

  void debug(String message) => log(Verbosity.debug, message);
  void info(String message) => log(Verbosity.info, message);
  void warn(String message) => log(Verbosity.warn, message);
  void error(String message) => log(Verbosity.error, message);

  void log(Verbosity verbosity, String message) {
    if (kDebugMode && verbosity.index >= sdkVerbosity.index) {
      final prefixString = useEmoji
          ? '[Datadog 🐶${_emojiMap[verbosity]}]'
          : '[Datadog - ${verbosity.name}]';
      // ignore: avoid_print
      print('$prefixString $message');
    }
  }

  // Standard error strings
  static String argumentWarning(String methodName, ArgumentError e) =>
      'ArgumentError when calling $methodName: parameter ${e.name} could not be properly converted to a supported native type.';
}
