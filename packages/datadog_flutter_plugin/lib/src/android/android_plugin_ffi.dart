// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.


import 'package:jni/jni.dart';

import '../../datadog_internal.dart';
import 'datadog_android_bridge.dart' as bridge;

class AndroidDatadogFlutterPlugin {
  static final JString _javaRumKey = 'rum'.toJString();
  static final JString _javaSessionId = 'session_id'.toJString();

  static DatadogContext? getContext() {
    final companion = bridge.DatadogSdkPlugin.Companion;
    final javaContext = companion.coreContext;
    if (javaContext == null) return null;

    String? sessionId;
    final featuresContext = javaContext.featuresContext;
    final rumContext = featuresContext.get(_javaRumKey);
    if (rumContext != null) {
      final javaSessionId = rumContext.get(_javaSessionId);
      if (javaSessionId != null) {
        sessionId = javaSessionId.toString();
      }
    }

    final accountInfo = javaContext.accountInfo;
    final accountId = accountInfo?.id.toDartString();

    final userInfo = javaContext.userInfo;
    final userId = userInfo.id?.toDartString();

    return DatadogContext(
      sessionId: sessionId,
      accountId: accountId,
      userId: userId,
    );
  }
}
