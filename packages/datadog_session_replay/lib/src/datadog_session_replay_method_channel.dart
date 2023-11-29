// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../datadog_session_replay.dart';
import 'datadog_session_replay.dart';
import 'datadog_session_replay_platform_interface.dart';

/// An implementation of [DatadogSessionReplayPlatform] that uses method channels.
class MethodChannelDatadogSessionReplay extends DatadogSessionReplayPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel =
      const MethodChannel('datadog_sdk_flutter.session_replay');

  @override
  Future<void> enable(DatadogSessionReplayConfiguration configuration,
      void Function(RUMContext) onContextChanged) async {
    // All we actually need at the moment is the customEndpoint if set
    final arguments = {
      'configuration': {'customEndpoint': configuration.customEndpoint}
    };
    methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onContextChanged') {
        final contextMap = call.arguments as Map<Object?, Object?>;
        final context = RUMContext.fromMap(contextMap);
        onContextChanged(context);
      }
    });
    await methodChannel.invokeMethod('enable', arguments);
    // TODO: Check result
  }

  @override
  Future<void> writeSegment(String record, String viewId) {
    final arguments = {'record': record, 'viewId': viewId};
    return methodChannel.invokeMethod('writeSegment', arguments);
  }
}
