// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'ddlogs_platform_interface.dart';

class DdLogs {
  static DdLogsPlatform get _platform {
    return DdLogsPlatform.instance;
  }

  Future<void> debug(String message,
      [Map<String, Object?> context = const {}]) {
    return _platform.debug(message, context);
  }

  Future<void> info(String message, [Map<String, Object?> context = const {}]) {
    return _platform.info(message, context);
  }

  Future<void> warn(String message, [Map<String, Object?> context = const {}]) {
    return _platform.warn(message, context);
  }

  Future<void> error(String message,
      [Map<String, Object?> context = const {}]) {
    return _platform.error(message, context);
  }
}
