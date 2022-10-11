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

  test('attachToExsiting calls to methodChannel', () {
    unawaited(ddSdkPlatform.attachToExisting());

    expect(log, [
      isMethodCall('attachToExisting', arguments: <String, Object>{}),
    ]);
  });

  test('attachToExisting response properly returns null from platform',
      () async {
    // The mock method channel is already set up to return null, so this should
    // just pass it through.
    final response = await ddSdkPlatform.attachToExisting();

    expect(response, isNull);
  });

  test('attachToExisting response properly deserializes response', () async {
    ddSdkPlatform.methodChannel.setMockMethodCallHandler((call) {
      log.add(call);
      if (call.method == 'attachToExisting') {
        return Future<Map<String, Object?>>.value(
            {'loggingEnabled': true, 'rumEnabled': false});
      }

      return null;
    });
    final response = await ddSdkPlatform.attachToExisting();

    expect(response, isNotNull);
    if (response != null) {
      expect(response.rumEnabled, false);
    }
  });

  test('invalid attachToExisting response returns null', () async {
    ddSdkPlatform.methodChannel.setMockMethodCallHandler((call) {
      log.add(call);
      if (call.method == 'attachToExisting') {
        return Future<Map<String, Object?>>.value({'rumEnabled': 'string'});
      }

      return null;
    });
    final response = await ddSdkPlatform.attachToExisting();

    expect(response, isNull);
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
    unawaited(ddSdkPlatform
        .setUserInfo('fake_id', 'fake_name', 'fake_email', const {}));

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
    unawaited(ddSdkPlatform
        .setUserInfo('fake_id', null, null, const {'attribute': 124.3}));

    expect(log, [
      isMethodCall('setUserInfo', arguments: {
        'id': 'fake_id',
        'name': null,
        'email': null,
        'extraInfo': const {'attribute': 124.3}
      })
    ]);
  });

  test('sendTelemetryDebug calls to method channel', () {
    unawaited(ddSdkPlatform.sendTelemetryDebug('debug telemetry method'));

    expect(log, [
      isMethodCall('telemetryDebug', arguments: {
        'message': 'debug telemetry method',
      })
    ]);
  });

  test('sendTelemetryError calls to method channel', () {
    final st = StackTrace.current;
    unawaited(ddSdkPlatform.sendTelemetryError(
        'error telemetry method', st.toString(), 'fake error'));

    expect(log, [
      isMethodCall('telemetryError', arguments: {
        'message': 'error telemetry method',
        'stack': st.toString(),
        'kind': 'fake error',
      })
    ]);
  });
}
