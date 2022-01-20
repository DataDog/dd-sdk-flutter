// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import 'dart:async';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:datadog_sdk/datadog_sdk_method_channel.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatadogSdkMethodChannel ddSdkPlatform;
  final List<MethodCall> log = [];

  setUp(() {
    ddSdkPlatform = DatadogSdkMethodChannel();
    ddSdkPlatform.methodChannel.setMockMethodCallHandler((call) {
      log.add(call);
      return null;
    });
  });

  tearDown(() {
    log.clear();
  });

  test('initialize encodes default parameters to method channel', () async {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'environment',
      trackingConsent: TrackingConsent.granted,
    );
    await ddSdkPlatform.initialize(configuration);

    expect(log, [
      isMethodCall('initialize',
          arguments: {'configuration': configuration.encode()})
    ]);
  });

  test('setDebugVerbosity calls to method channel', () {
    unawaited(ddSdkPlatform.setSdkVerbosity(Verbosity.info));

    expect(log, [
      isMethodCall('setSdkVerbosity', arguments: {'value': 'Verbosity.info'})
    ]);
  });

  test('setTrackingConsent calls to method channel', () {
    unawaited(ddSdkPlatform.setTrackingConsent(TrackingConsent.notGranted));

    expect(log, [
      isMethodCall('setTrackingConsent',
          arguments: {'value': 'TrackingConsent.notGranted'})
    ]);
  });
}
