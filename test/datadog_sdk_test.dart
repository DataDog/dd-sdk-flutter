// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import 'package:datadog_sdk/datadog_sdk_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDatadogSdkPlatform
    with MockPlatformInterfaceMixin
    implements DatadogSdkPlatform {
  DdSdkConfiguration? configuration;

  @override
  Future<void> initialize(DdSdkConfiguration configuration) {
    this.configuration = configuration;
    return Future.value();
  }
}

void main() {
  late DatadogSdk datadogSdk;
  late MockDatadogSdkPlatform fakePlatform;

  setUp(() {
    fakePlatform = MockDatadogSdkPlatform();
    DatadogSdkPlatform.instance = fakePlatform;
    datadogSdk = DatadogSdk.instance;
  });

  test('initialize passes configuration to platform', () async {
    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      applicationId: 'applicationId',
      trackingConsent: TrackingConsent.pending,
    );
    await datadogSdk.initialize(configuration);
    expect(configuration, fakePlatform.configuration);
  });
}
