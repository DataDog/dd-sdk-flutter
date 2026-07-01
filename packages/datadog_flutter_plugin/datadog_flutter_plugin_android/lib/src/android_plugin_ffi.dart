// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:jni/jni.dart';

import 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart';
import 'datadog_android_bridge.dart' as bridge;

class AndroidDatadogFlutterPlugin {
  static final JString _javaRumKey = JString.fromString('rum');
  static final JString _javaSessionId = JString.fromString('session_id');

  static DatadogContext? getContext() {
    final javaContext = bridge.DatadogSdkPlugin.Companion.getCoreContext();
    if (javaContext == null) return null;

    String? sessionId;
    final rumContext = javaContext.getFeaturesContext()[_javaRumKey];
    if (rumContext != null) {
      final javaSessionId = rumContext[_javaSessionId];
      if (javaSessionId != null) {
        sessionId = javaSessionId.toString();
        javaSessionId.release();
      }
    }

    final context = DatadogContext(
      sessionId: sessionId,
      accountId: javaContext.getAccountInfo()?.getId().toDartString(),
      userId: javaContext.getUserInfo().getId()?.toDartString(),
    );
    javaContext.release();
    return context;
  }
}
