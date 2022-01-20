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
  Verbosity verbosity = Verbosity.none;

  @override
  Future<void> initialize(DdSdkConfiguration configuration,
      {LogCallback? logCallback}) {
    this.configuration = configuration;
    return Future.value();
  }

  @override
  Future<void> setSdkVerbosity(Verbosity verbosity) {
    this.verbosity = verbosity;
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
      trackingConsent: TrackingConsent.pending,
    );
    await datadogSdk.initialize(configuration);
    expect(configuration, fakePlatform.configuration);
  });

  test('encode base configuration', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fake-client-token',
      env: 'prod',
      trackingConsent: TrackingConsent.pending,
    );
    final encoded = configuration.encode();
    expect(encoded, {
      'clientToken': 'fake-client-token',
      'env': 'prod',
      'site': null,
      'nativeCrashReportEnabled': false,
      'trackingConsent': 'TrackingConsent.pending',
      'customEndpoint': null,
      'batchSize': null,
      'uploadFrequency': null,
      'loggingConfiguration': null,
      'tracingConfiguration': null,
      'rumConfiguration': null,
      'additionalConfig': {},
    });
  });

  test('initialize encoding serializes enums correctly', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'environment',
      trackingConsent: TrackingConsent.granted,
    )
      ..batchSize = BatchSize.small
      ..uploadFrequency = UploadFrequency.frequent
      ..site = DatadogSite.eu1;

    final encoded = configuration.encode();
    expect(encoded['batchSize'], 'BatchSize.small');
    expect(encoded['uploadFrequency'], 'UploadFrequency.frequent');
    expect(encoded['site'], 'DatadogSite.eu1');
  });

  test('configuration encodes default sub-configuration', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'fake-env',
      trackingConsent: TrackingConsent.notGranted,
      loggingConfiguration: LoggingConfiguration(),
      tracingConfiguration: TracingConfiguration(),
      rumConfiguration: RumConfiguration(applicationId: 'fake-application-id'),
    );

    final encoded = configuration.encode();
    expect(encoded['loggingConfiguration'],
        configuration.loggingConfiguration?.encode());
    expect(encoded['tracingConfiguration'],
        configuration.tracingConfiguration?.encode());
    expect(
        encoded['rumConfiguration'], configuration.rumConfiguration?.encode());
  });
}
