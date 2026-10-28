// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:jni/jni.dart';

import 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart';
import 'datadog_android_bridge.dart' as bridge;

class AndroidDatadogFlutterPlugin {
  static final JString _javaRumKey = 'rum'.toJString();
  static final JString _javaSessionId = 'session_id'.toJString();
  static final JString _javaSessionSampleRate = 'session_sample_rate'
      .toJString();
  static final JString _javaTracingKey = 'tracing'.toJString();
  // Must match TracingInterceptor.OKHTTP_INTERCEPTOR_SAMPLE_RATE in
  // dd-sdk-android-okhttp, and TracingContextFeature.TRACE_SAMPLE_RATE_KEY.
  static final JString _javaTraceSampleRate = 'okhttp_interceptor_sample_rate'
      .toJString();

  static DatadogContext? getContext() {
    final javaContext = bridge.DatadogSdkPlugin.Companion.coreContext;
    if (javaContext == null) return null;

    String? sessionId;
    double? sessionSampleRate;
    final rumContext = javaContext.featuresContext.get(_javaRumKey);
    if (rumContext != null) {
      final javaSessionId = rumContext.get(_javaSessionId);
      if (javaSessionId != null) {
        sessionId = javaSessionId.toString();
        javaSessionId.release();
      }
      final javaSessionSampleRate = rumContext.get(_javaSessionSampleRate);
      if (javaSessionSampleRate != null) {
        // Stored by native RUM as a Float.
        sessionSampleRate = (javaSessionSampleRate as JNumber).doubleValue();
        javaSessionSampleRate.release();
      }
    }

    double? traceSampleRate;
    final tracingContext = javaContext.featuresContext.get(_javaTracingKey);
    if (tracingContext != null) {
      final javaTraceSampleRate = tracingContext.get(_javaTraceSampleRate);
      if (javaTraceSampleRate != null) {
        // Stored by native tracing (or Flutter's stand-in for it) as a Float.
        traceSampleRate = (javaTraceSampleRate as JNumber).doubleValue();
        javaTraceSampleRate.release();
      }
    }

    final context = DatadogContext(
      sessionId: sessionId,
      accountId: javaContext.accountInfo?.id.toDartString(),
      userId: javaContext.userInfo.id?.toDartString(),
      sessionSampleRate: sessionSampleRate,
      traceSampleRate: traceSampleRate,
    );
    javaContext.release();
    return context;
  }
}
