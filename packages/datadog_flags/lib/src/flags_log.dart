// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:developer' as developer;

/// Severity of a `datadog_flags` diagnostic message.
enum FlagsLoggerLevel {
  debug(500),
  warning(900),
  error(1000);

  const FlagsLoggerLevel(this._developerLogLevel);

  final int _developerLogLevel;
}

typedef DeveloperLog =
    void Function(String message, {String name, int level, Object? error});

/// Writes SDK diagnostics to the Dart developer log, and prints the ones at or
/// above [printLevel].
class FlagsLogger {
  const FlagsLogger({DeveloperLog log = developer.log}) : _log = log;

  /// Lowest level to print, or `null` to print nothing.
  static FlagsLoggerLevel? printLevel;

  final DeveloperLog _log;

  void error(String message, {Object? error}) =>
      _write(FlagsLoggerLevel.error, message, error);

  void warning(String message, {Object? error}) =>
      _write(FlagsLoggerLevel.warning, message, error);

  void debug(String message, {Object? error}) =>
      _write(FlagsLoggerLevel.debug, message, error);

  void _write(FlagsLoggerLevel level, String message, Object? error) {
    _log(
      message,
      name: 'datadog_flags',
      level: level._developerLogLevel,
      error: error,
    );
    if (printLevel case final threshold? when level.index >= threshold.index) {
      final details = error == null ? '' : ' $error';
      print('[Datadog Flags - ${level.name}] $message$details');
    }
  }
}
