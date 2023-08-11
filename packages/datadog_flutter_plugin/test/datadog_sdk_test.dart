// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_flutter_plugin/src/logs/ddlogs_platform_interface.dart';
import 'package:datadog_flutter_plugin/src/rum/ddrum_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDatadogSdkPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DatadogSdkPlatform {}

class MockDdLogsPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DdLogsPlatform {}

class FakeDdSdkConfiguration extends Fake implements DdSdkConfiguration {}

class MockDatadogPluginConfiguration extends Mock
    implements DatadogPluginConfiguration {}

class MockDatadogPlugin extends Mock implements DatadogPlugin {}

class MockRumPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DdRumPlatform {}

void main() {
  late DatadogSdk datadogSdk;
  late MockDatadogSdkPlatform mockPlatform;
  late MockDdLogsPlatform mockLogsPlatform;
  late MockRumPlatform mockRumPlatform;

  setUpAll(() {
    registerFallbackValue(FakeDdSdkConfiguration());
    registerFallbackValue(TrackingConsent.granted);
    registerFallbackValue(LoggingConfiguration());
    registerFallbackValue(LateConfigurationProperty.trackErrors);
    registerFallbackValue(Verbosity.verbose);
    registerFallbackValue(InternalLogger());
    registerFallbackValue(RumConfiguration(applicationId: ''));
  });

  setUp(() {
    mockPlatform = MockDatadogSdkPlatform();
    when(() => mockPlatform.initialize(
              any(),
              internalLogger: any(named: 'internalLogger'),
              logCallback: any(named: 'logCallback'),
            ))
        .thenAnswer((_) => Future<PlatformInitializationResult>.value(
            const PlatformInitializationResult(logs: true, rum: true)));
    when(() => mockPlatform.attachToExisting())
        .thenAnswer((_) => Future<AttachResponse?>.value(AttachResponse(
              rumEnabled: false,
            )));
    when(() => mockPlatform.setSdkVerbosity(any()))
        .thenAnswer((invocation) => Future<void>.value());

    when(() => mockPlatform.setUserInfo(any(), any(), any(), any()))
        .thenAnswer((_) => Future<void>.value());
    when(() => mockPlatform.addUserExtraInfo((any())))
        .thenAnswer((_) => Future<void>.value());
    when(() => mockPlatform.setTrackingConsent(any()))
        .thenAnswer((_) => Future<void>.value());
    when(() => mockPlatform.flushAndDeinitialize())
        .thenAnswer((_) => Future<void>.value());
    when(() => mockPlatform.updateTelemetryConfiguration(any(), any()))
        .thenAnswer((_) => Future<void>.value());
    DatadogSdkPlatform.instance = mockPlatform;
    datadogSdk = DatadogSdk.instance;

    mockLogsPlatform = MockDdLogsPlatform();
    DdLogsPlatform.instance = mockLogsPlatform;

    mockRumPlatform = MockRumPlatform();
    when(() => mockRumPlatform.initialize(any(), any()))
        .thenAnswer((_) => Future<void>.value());
    DdRumPlatform.instance = mockRumPlatform;
  });

  tearDown(() async {
    await datadogSdk.flushAndDeinitialize();
  });

  test('initialize passes configuration to platform', () async {
    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
    );
    await datadogSdk.initialize(configuration);

    verify(() => mockPlatform.initialize(
          configuration,
          internalLogger: any(named: 'internalLogger'),
          logCallback: any(named: 'logCallback'),
        ));
  });

  test('encode base configuration', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fake-client-token',
      env: 'prod',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
    );
    final encoded = configuration.encode();
    expect(encoded, {
      'clientToken': 'fake-client-token',
      'env': 'prod',
      'site': 'DatadogSite.us1',
      'serviceName': null,
      'nativeCrashReportEnabled': false,
      'trackingConsent': 'TrackingConsent.pending',
      'telemetrySampleRate': null,
      'customLogsEndpoint': null,
      'batchSize': null,
      'uploadFrequency': null,
      'firstPartyHosts': <String>[],
      'rumConfiguration': null,
      'additionalConfig': <String, Object?>{},
      'attachLogMapper': false,
    });
  });

  test('initialize encoding serializes enums correctly', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'environment',
      site: DatadogSite.us1,
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

  test('configuration encodes telemetrySampleRate', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fake-client-token',
      env: 'prod',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      telemetrySampleRate: 21.0,
    );
    final encoded = configuration.encode();
    expect(encoded['telemetrySampleRate'], 21.0);
  });

  test('configuration encodes serviceName', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'fake-env',
      serviceName: 'com.servicename',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.notGranted,
    );

    final encoded = configuration.encode();
    // Logging configuration is purposefully not encoded
    expect(encoded['serviceName'], 'com.servicename');
  });

  test('version added to additionalConfiguration', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'fake-env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.notGranted,
      version: '1.9.8+123',
    );

    final encoded = configuration.encode();
    final additionalConfig =
        encoded['additionalConfig'] as Map<String, Object?>;
    expect(additionalConfig[DatadogConfigKey.version], '1.9.8-123');
  });

  test('flavor added to additionalConfiguration', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'fake-env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.notGranted,
      flavor: 'strawberry',
    );

    final encoded = configuration.encode();
    final additionalConfig =
        encoded['additionalConfig'] as Map<String, Object?>;
    expect(additionalConfig[DatadogConfigKey.variant], 'strawberry');
  });

  test('configuration encodes default sub-configuration', () {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'fake-env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.notGranted,
      loggingConfiguration: LoggingConfiguration(),
      rumConfiguration: RumConfiguration(
        applicationId: 'fake-application-id',
        vitalUpdateFrequency: VitalsFrequency.frequent,
      ),
    );

    final encoded = configuration.encode();
    // Logging configuration is purposefully not encoded
    expect(encoded['loggingConfiguration'], isNull);
    expect(
        encoded['rumConfiguration'], configuration.rumConfiguration?.encode());
  });

  test('configuration with mapper sets attach*Mapper', () async {
    final configuration = DdSdkConfiguration(
      clientToken: 'fakeClientToken',
      env: 'fake-env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.notGranted,
      loggingConfiguration: LoggingConfiguration(),
      rumConfiguration: RumConfiguration(
        applicationId: 'fake-application-id',
        rumViewEventMapper: (event) => event,
        rumActionEventMapper: (event) => event,
        rumResourceEventMapper: (event) => event,
        rumErrorEventMapper: (event) => event,
        rumLongTaskEventMapper: (event) => event,
      ),
    );

    final encoded = configuration.encode();
    final encodedRumConfiguration =
        encoded['rumConfiguration'] as Map<String, Object?>;
    expect(encodedRumConfiguration['attachViewEventMapper'], isTrue);
    expect(encodedRumConfiguration['attachActionEventMapper'], isTrue);
    expect(encodedRumConfiguration['attachResourceEventMapper'], isTrue);
    expect(encodedRumConfiguration['attachErrorEventMapper'], isTrue);
    expect(encodedRumConfiguration['attachLongTaskEventMapper'], isTrue);
  });

  test('initialize with logging configuration creates logger', () async {
    when(() => mockLogsPlatform.createLogger(any(), any()))
        .thenAnswer((_) => Future<void>.value());

    final loggingConfiguration = LoggingConfiguration();
    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      loggingConfiguration: loggingConfiguration,
    );
    await datadogSdk.initialize(configuration);

    final logger = datadogSdk.logs;

    expect(logger, isNotNull);
    verify(() => mockLogsPlatform.createLogger(
        logger!.loggerHandle, loggingConfiguration));
  });

  test(
      'initialize with logging configuration does not create logger on platform init failure',
      () async {
    when(() => mockPlatform.initialize(
              any(),
              internalLogger: any(named: 'internalLogger'),
              logCallback: any(named: 'logCallback'),
            ))
        .thenAnswer((_) => Future<PlatformInitializationResult>.value(
            const PlatformInitializationResult(logs: false, rum: true)));

    final loggingConfiguration = LoggingConfiguration();
    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      loggingConfiguration: loggingConfiguration,
    );
    await datadogSdk.initialize(configuration);

    final logger = datadogSdk.logs;
    expect(logger, isNull);
    verifyNever(() => mockLogsPlatform.createLogger(any(), any()));
  });

  test(
      'initialize with rum configuration does not create RUM on platform init failure',
      () async {
    when(() => mockPlatform.initialize(
              any(),
              internalLogger: any(named: 'internalLogger'),
              logCallback: any(named: 'logCallback'),
            ))
        .thenAnswer((_) => Future<PlatformInitializationResult>.value(
            const PlatformInitializationResult(logs: true, rum: false)));

    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      rumConfiguration: RumConfiguration(
        applicationId: 'fake-application-id',
        vitalUpdateFrequency: VitalsFrequency.frequent,
      ),
    );
    await datadogSdk.initialize(configuration);

    final rum = datadogSdk.rum;
    expect(rum, isNull);
    verifyNever(() => mockRumPlatform.initialize(any(), any()));
  });

  test('attachToExisting calls out to platform', () async {
    await datadogSdk.attachToExisting(DdSdkExistingConfiguration());

    verify(() => mockPlatform.attachToExisting());
    expect(datadogSdk.rum, isNull);
    expect(datadogSdk.logs, isNull);
  });

  test('attachToExisting forwards creation firstPartyHosts', () async {
    when(() => mockPlatform.attachToExisting()).thenAnswer(
        (invocation) => Future<AttachResponse?>.value(AttachResponse(
              rumEnabled: false,
            )));

    await datadogSdk.attachToExisting(DdSdkExistingConfiguration(
      firstPartyHosts: ['example.com', 'datadoghq.com'],
    ));

    expect(datadogSdk.firstPartyHosts.length, 2);
    expect(datadogSdk.firstPartyHosts[0].hostName, 'example.com');
    expect(datadogSdk.firstPartyHosts[1].hostName, 'datadoghq.com');
  });

  test('attachToExisting with loggingConfiguration creates default logger',
      () async {
    when(() => mockPlatform.attachToExisting()).thenAnswer(
        (invocation) => Future<AttachResponse?>.value(AttachResponse(
              rumEnabled: false,
            )));
    when(() => mockLogsPlatform.createLogger(any(), any()))
        .thenAnswer((_) => Future<void>.value());
    final logConfig = LoggingConfiguration();

    await datadogSdk.attachToExisting(
      DdSdkExistingConfiguration(
        loggingConfiguration: logConfig,
        detectLongTasks: false,
      ),
    );

    expect(datadogSdk.logs, isNotNull);
    verify(() => mockLogsPlatform.createLogger(any(), logConfig));
  });

  test('attachToExisting without loggingConfiguration does not create logger',
      () async {
    when(() => mockPlatform.attachToExisting()).thenAnswer(
        (invocation) => Future<AttachResponse?>.value(AttachResponse(
              rumEnabled: false,
            )));

    await datadogSdk.attachToExisting(DdSdkExistingConfiguration(
      detectLongTasks: false,
    ));
    expect(datadogSdk.logs, null);
  });

  test('attachToExisting with rumEnabled creates RUM bridge', () async {
    when(() => mockPlatform.attachToExisting()).thenAnswer(
        (invocation) => Future<AttachResponse?>.value(AttachResponse(
              rumEnabled: true,
            )));

    await datadogSdk.attachToExisting(DdSdkExistingConfiguration(
      detectLongTasks: false,
    ));
    expect(datadogSdk.rum, isNotNull);
  });

  test('attachToExisting with rumEnabled forwards RUM parameters', () async {
    when(() => mockPlatform.attachToExisting()).thenAnswer(
        (invocation) => Future<AttachResponse?>.value(AttachResponse(
              rumEnabled: true,
            )));

    await datadogSdk.attachToExisting(DdSdkExistingConfiguration(
      longTaskThreshold: 0.5,
      tracingSamplingRate: 100.0,
      detectLongTasks: false,
    ));

    expect(datadogSdk.rum?.configuration.longTaskThreshold, 0.5);
    expect(datadogSdk.rum?.configuration.tracingSamplingRate, 100.0);
  });

  test('first party hosts get set to sdk', () async {
    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHosts: ['example.com', 'datadoghq.com'],
    );
    await datadogSdk.initialize(configuration);

    expect(datadogSdk.firstPartyHosts.length, 2);
    expect(datadogSdk.firstPartyHosts[0].hostName, 'example.com');
    expect(
        datadogSdk.firstPartyHosts[0].headerTypes, {TracingHeaderType.datadog});
    expect(datadogSdk.firstPartyHosts[1].hostName, 'datadoghq.com');
    expect(
        datadogSdk.firstPartyHosts[1].headerTypes, {TracingHeaderType.datadog});
  });

  test('first party hosts with tracing headers set to sdk', () async {
    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHostsWithTracingHeaders: {
        'example.com': {TracingHeaderType.b3},
        'datadoghq.com': {TracingHeaderType.datadog},
      },
    );
    await datadogSdk.initialize(configuration);

    expect(datadogSdk.firstPartyHosts.length, 2);
    expect(datadogSdk.firstPartyHosts[0].hostName, 'example.com');
    expect(datadogSdk.firstPartyHosts[0].headerTypes, {TracingHeaderType.b3});
    expect(datadogSdk.firstPartyHosts[1].hostName, 'datadoghq.com');
    expect(
        datadogSdk.firstPartyHosts[1].headerTypes, {TracingHeaderType.datadog});
  });

  test('first party hosts combined tracing headers set to sdk', () async {
    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHosts: ['datadoghq.com'],
      firstPartyHostsWithTracingHeaders: {
        'example.com': {TracingHeaderType.b3},
      },
    );
    await datadogSdk.initialize(configuration);

    expect(datadogSdk.firstPartyHosts.length, 2);
    expect(datadogSdk.firstPartyHosts[0].hostName, 'example.com');
    expect(datadogSdk.firstPartyHosts[0].headerTypes, {TracingHeaderType.b3});
    expect(datadogSdk.firstPartyHosts[1].hostName, 'datadoghq.com');
    expect(
        datadogSdk.firstPartyHosts[1].headerTypes, {TracingHeaderType.datadog});
  });

  test('first party hosts are encoded', () async {
    var firstPartyHosts = ['example.com', 'datadoghq.com'];

    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHosts: firstPartyHosts,
    );

    final encoded = configuration.encode();
    expect(encoded['firstPartyHosts'], firstPartyHosts);
  });

  test('headerTypesForHost with no hosts returns empty set', () async {
    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
    );
    await datadogSdk.initialize(configuration);

    var uri = Uri.parse('https://first_party');
    expect(datadogSdk.headerTypesForHost(uri), isEmpty);
  });

  test('headerTypesForHost with matching host returns datadog by default',
      () async {
    var firstPartyHosts = ['example.com', 'datadoghq.com'];

    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHosts: firstPartyHosts,
    );
    await datadogSdk.initialize(configuration);

    var uri = Uri.parse('https://datadoghq.com/path');
    expect(datadogSdk.headerTypesForHost(uri), {TracingHeaderType.datadog});
  });

  test(
      'headerTypesForHost with matching host with subdomain returns header type',
      () async {
    var firstPartyHosts = ['example.com', 'datadoghq.com'];

    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHosts: firstPartyHosts,
    );
    await datadogSdk.initialize(configuration);

    var uri = Uri.parse('https://test.datadoghq.com/path');
    expect(datadogSdk.headerTypesForHost(uri), {TracingHeaderType.datadog});
  });

  test('headerTypesForHost with matching subdomain does not match root',
      () async {
    var firstPartyHosts = ['example.com', 'test.datadoghq.com'];

    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHosts: firstPartyHosts,
    );
    await datadogSdk.initialize(configuration);

    var uri = Uri.parse('https://datadoghq.com/path');
    expect(datadogSdk.headerTypesForHost(uri), isEmpty);
  });

  test('headerTypesForHost escapes special characters in hosts', () async {
    var firstPartyHosts = ['test.datadoghq.com'];

    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHosts: firstPartyHosts,
    );
    await datadogSdk.initialize(configuration);

    var uri = Uri.parse('https://testdatadoghq.com/path');
    expect(datadogSdk.headerTypesForHost(uri), isEmpty);
  });

  test('headerTypesForHost merges header types', () async {
    var firstPartyHosts = {
      'datadoghq.com': {TracingHeaderType.datadog},
      'test.datadoghq.com': {TracingHeaderType.b3},
    };

    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHostsWithTracingHeaders: firstPartyHosts,
    );
    await datadogSdk.initialize(configuration);

    var uri = Uri.parse('https://test.datadoghq.com/path');
    expect(datadogSdk.headerTypesForHost(uri),
        {TracingHeaderType.datadog, TracingHeaderType.b3});
  });

  test('firstPartyHosts sanitizes schemas', () async {
    var firstPartyHosts = {
      'https://datadoghq.com': {TracingHeaderType.datadog},
      'http://test.datadoghq.com': {TracingHeaderType.b3},
      'ws://ws.datadoghq.com': {TracingHeaderType.b3multi},
    };

    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
      firstPartyHostsWithTracingHeaders: firstPartyHosts,
    );
    await datadogSdk.initialize(configuration);

    expect(datadogSdk.firstPartyHosts.length, 3);
    expect(datadogSdk.firstPartyHosts[0].hostName, 'datadoghq.com');
    expect(
        datadogSdk.firstPartyHosts[0].headerTypes, {TracingHeaderType.datadog});
    expect(datadogSdk.firstPartyHosts[1].hostName, 'test.datadoghq.com');
    expect(datadogSdk.firstPartyHosts[1].headerTypes, {TracingHeaderType.b3});
    expect(datadogSdk.firstPartyHosts[2].hostName, 'ws.datadoghq.com');
    expect(
        datadogSdk.firstPartyHosts[2].headerTypes, {TracingHeaderType.b3multi});
  });

  test('set user info calls into platform', () {
    datadogSdk.setUserInfo(
        id: 'fake_id', name: 'fake_name', email: 'fake_email');

    verify(() =>
        mockPlatform.setUserInfo('fake_id', 'fake_name', 'fake_email', {}));
  });

  test('set user info calls into platform passing extraInfo', () {
    datadogSdk.setUserInfo(
      id: 'fake_id',
      name: 'fake_name',
      email: 'fake_email',
      extraInfo: {'attribute': 32.0},
    );

    verify(() => mockPlatform.setUserInfo(
          'fake_id',
          'fake_name',
          'fake_email',
          {'attribute': 32.0},
        ));
  });

  test('set user info calls into platform passing null values', () {
    datadogSdk.setUserInfo(id: null, name: null, email: null);

    verify(() => mockPlatform.setUserInfo(null, null, null, {}));
  });

  test('addUserExtraInfo passes through to platform', () {
    datadogSdk.addUserExtraInfo({
      'example_1': 'test',
      'example_2': null,
    });

    verify(() => mockPlatform.addUserExtraInfo({
          'example_1': 'test',
          'example_2': null,
        }));
  });

  test('set tracking consent calls into platform', () {
    datadogSdk.setTrackingConsent(TrackingConsent.notGranted);

    verify(() => mockPlatform.setTrackingConsent(TrackingConsent.notGranted));
  });

  test('createLogger calls into logs platform', () {
    when(() => mockLogsPlatform.createLogger(any(), any()))
        .thenAnswer((_) => Future<void>.value());
    final config = LoggingConfiguration(loggerName: 'test_logger');

    final logger = datadogSdk.createLogger(config);

    expect(logger, isNotNull);
    verify(() => mockLogsPlatform.createLogger(logger.loggerHandle, config));
  });

  test('plugin added to configuration is created during initialization',
      () async {
    final mockPluginConfig = MockDatadogPluginConfiguration();
    final mockPlugin = MockDatadogPlugin();
    when(() => mockPluginConfig.create(datadogSdk))
        .thenAnswer((_) => mockPlugin);

    final config = DdSdkConfiguration(
      clientToken: 'fake_token',
      env: 'env',
      trackingConsent: TrackingConsent.granted,
      site: DatadogSite.us1,
    )..addPlugin(mockPluginConfig);

    await datadogSdk.initialize(config);

    verify(() => mockPluginConfig.create(datadogSdk));
    verify(() => mockPlugin.initialize());
    expect(datadogSdk.getPlugin<MockDatadogPlugin>(), mockPlugin);
  });

  test('plugin added to configuration is created during attachToExisting',
      () async {
    when(() => mockPlatform.attachToExisting()).thenAnswer(
        (invocation) => Future<AttachResponse?>.value(AttachResponse(
              rumEnabled: false,
            )));

    final mockPluginConfig = MockDatadogPluginConfiguration();
    final mockPlugin = MockDatadogPlugin();
    when(() => mockPluginConfig.create(datadogSdk))
        .thenAnswer((_) => mockPlugin);

    final config = DdSdkExistingConfiguration()..addPlugin(mockPluginConfig);

    await datadogSdk.attachToExisting(config);

    verify(() => mockPluginConfig.create(datadogSdk));
    verify(() => mockPlugin.initialize());
    expect(datadogSdk.getPlugin<MockDatadogPlugin>(), mockPlugin);
  });

  test('updateConfigurationInfo calls to platform', () async {
    final configuration = DdSdkConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.pending,
    );
    await datadogSdk.initialize(configuration);

    datadogSdk.updateConfigurationInfo(
        LateConfigurationProperty.trackInteractions, true);
    datadogSdk.updateConfigurationInfo(
        LateConfigurationProperty.trackViewsManually, false);

    verify(() =>
        mockPlatform.updateTelemetryConfiguration('trackInteractions', true));
    verify(() =>
        mockPlatform.updateTelemetryConfiguration('trackViewsManually', false));
  });
}
