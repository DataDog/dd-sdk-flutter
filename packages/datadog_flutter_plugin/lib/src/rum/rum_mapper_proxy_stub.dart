// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../datadog_flutter_plugin.dart';
import '../../datadog_internal.dart';

class RumMapperProxy {
  static RumMapperProxy? fromConfiguration(
    DatadogRumConfiguration config,
    InternalLogger logger,
  ) {
    if (!kIsWeb) {
      logger.sendToDatadog(
        'Attempting to make a stub RumMapperProxy on non web platform!',
        StackTrace.current,
        'InvalidOperation',
      );
    }
    return null;
  }
}

class RumMethodChannelMapperProxy extends RumMapperProxy {
  void handleMethodCall(MethodCall methodCall) {}
}
