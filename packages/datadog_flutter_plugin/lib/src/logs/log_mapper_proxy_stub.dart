// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/foundation.dart';

import '../../datadog_flutter_plugin.dart';
import '../../datadog_internal.dart';

class LogMapperProxy {
  static LogMapperProxy? fromConfiguration(
    DatadogLoggingConfiguration config,
    InternalLogger logger,
  ) {
    if (!kIsWeb) {
      logger.sendToDatadog(
        'Attempting to make a stub LogMapperProxy on non web platform!',
        StackTrace.current,
        'InvalidOperation',
      );
    }
    return null;
  }
}
