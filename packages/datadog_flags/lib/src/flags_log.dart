// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:developer' as developer;

/// Writes SDK diagnostics to the Dart developer log.
class FlagsLogger {
  const FlagsLogger();

  void error(String message, {Object? error}) =>
      developer.log(message, name: 'datadog_flags', level: 1000, error: error);
}
