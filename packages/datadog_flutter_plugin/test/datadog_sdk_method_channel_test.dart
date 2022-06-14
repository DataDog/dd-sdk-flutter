// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/src/datadog_sdk_method_channel.dart';
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
      site: DatadogSite.us1,
    );
    await ddSdkPlatform.initialize(configuration);

    expect(log, [
      isMethodCall('initialize', arguments: {
        'configuration': configuration.encode(),
        'setLogCallback': false,
      })
    ]);
  });

  test('initialize add setLogCallback when provided', () async {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'environment',
      trackingConsent: TrackingConsent.granted,
      site: DatadogSite.us1,
    );
    await ddSdkPlatform.initialize(configuration, logCallback: (_) {});

    expect(log, [
      isMethodCall('initialize', arguments: {
        'configuration': configuration.encode(),
        'setLogCallback': true,
      })
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

  test('setUserInfo calls to method channel', () {
    unawaited(ddSdkPlatform.setUserInfo(
        'fake_id', 'fake_name', 'fake_email', const <String, Object?>{}));

    expect(log, [
      isMethodCall('setUserInfo', arguments: {
        'id': 'fake_id',
        'name': 'fake_name',
        'email': 'fake_email',
        'extraInfo': const <String, Object?>{}
      })
    ]);
  });

  test('setUserInfo calls to method channel passing attributes and nulls', () {
    unawaited(ddSdkPlatform.setUserInfo(
        'fake_id', null, null, const <String, Object?>{'attribute': 124.3}));

    expect(log, [
      isMethodCall('setUserInfo', arguments: {
        'id': 'fake_id',
        'name': null,
        'email': null,
        'extraInfo': const {'attribute': 124.3}
      })
    ]);
  });
}
