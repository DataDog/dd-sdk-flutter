// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:jni/jni.dart';

import 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart';
import 'datadog_android_bridge.dart' as bridge;

class AndroidDatadogFlutterPlugin {
  static DatadogContext? getContext() {
    return using((arena) {
      final companion = bridge.DatadogSdkPlugin.Companion..releasedBy(arena);
      final javaContext = companion.coreContext?..releasedBy(arena);
      if (javaContext == null) return null;

      final sessionId = companion
          .getRumSessionId(javaContext)
          ?.toDartString(releaseOriginal: true);
      final accountInfo = javaContext.accountInfo?..releasedBy(arena);
      final userInfo = javaContext.userInfo..releasedBy(arena);

      return DatadogContext(
        sessionId: sessionId,
        accountId: accountInfo?.id.toDartString(releaseOriginal: true),
        userId: userInfo.id?.toDartString(releaseOriginal: true),
      );
    });
  }
}
