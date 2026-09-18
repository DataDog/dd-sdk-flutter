// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:io';

import 'package:jni/jni.dart';
import 'package:objective_c/objective_c.dart';

import 'android/datadog_session_replay_platform_android.dart';
import 'datadog_session_replay_platform_interface.dart';
import 'ios/datadog_session_replay_platform_ios.dart';

void initSessionReplayPlatform() {
  if (Platform.isIOS) {
    DatadogSessionReplayPlatform.instance = DatadogSessionReplayPlatformIos();
  } else {
    DatadogSessionReplayPlatform.instance =
        DatadogSessionReplayPlatformAndroid();
  }
}

void attachSessionReplayToIsolate(Object? isolateToken) {
  // Isolates aren't a thing on web
  if (Platform.isIOS) {
    if (isolateToken is ObjCObjectBase) {
      DatadogSessionReplayPlatform.instance =
          DatadogSessionReplayPlatformIos.fromObjCRef(isolateToken);
    }
  } else {
    if (isolateToken is JObject) {
      DatadogSessionReplayPlatform.instance =
          DatadogSessionReplayPlatformAndroid.fromJObject(isolateToken);
    }
  }
}
