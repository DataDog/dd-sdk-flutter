// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

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

    expect(log, <Matcher>[
      isMethodCall('initialize', arguments: {
        'configuration': <String, dynamic>{
          'clientToken': 'fakeClientToken',
          'env': 'environment',
          'applicationId': null,
          'nativeCrashReportEnabled': false,
          'sampleRate': 100.0,
          'site': null,
          'batchSize': null,
          'uploadFrequency': null,
          'trackingConsent': 'TrackingConsent.granted',
          'customEndpoint': null,
          'additionalConfig': {},
        }
      })
    ]);
  });

  test('initialize encoding serializes enums correctly', () async {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'environment',
      trackingConsent: TrackingConsent.granted,
    )
      ..batchSize = BatchSize.small
      ..uploadFrequency = UploadFrequency.frequent
      ..site = DatadogSite.eu1;

    await ddSdkPlatform.initialize(configuration);

    expect(log, <Matcher>[
      isMethodCall('initialize', arguments: {
        'configuration': <String, dynamic>{
          'clientToken': 'fakeClientToken',
          'env': 'environment',
          'applicationId': null,
          'nativeCrashReportEnabled': false,
          'sampleRate': 100.0,
          'site': 'DatadogSite.eu1',
          'batchSize': 'BatchSize.small',
          'uploadFrequency': 'UploadFrequency.frequent',
          'trackingConsent': 'TrackingConsent.granted',
          'customEndpoint': null,
          'additionalConfig': {},
        }
      })
    ]);
  });
}
