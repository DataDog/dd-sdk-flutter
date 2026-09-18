// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024-Present Datadog, Inc.
import 'dart:math';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_inappwebview_tracking/src/datadog_inappwebview_tracking_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelDatadogInAppWebViewTracking platform =
      MethodChannelDatadogInAppWebViewTracking();
  const MethodChannel channel = MethodChannel('datadog_inappwebview_tracking');

  List<MethodCall> callLog = [];

  setUp(() {
    callLog.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        callLog.add(methodCall);
        return null;
      },
    );
  });

  test('sendMessage sends correct parameters to method channel', () {
    final fakeMessage = randomString();
    final fakeSampleRate = Random().nextDouble() * 100;
    platform.sendWebViewMessage(fakeMessage, fakeSampleRate);

    expect(callLog.length, 1);
    final methodCall = callLog.first;
    final arguments = methodCall.arguments;
    expect(arguments is Map, isTrue);
    if (arguments is Map) {
      expect(arguments['message'], fakeMessage);
      expect(arguments['logSampleRate'], fakeSampleRate);
    }
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
