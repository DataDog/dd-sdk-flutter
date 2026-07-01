// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockDatadogFlags extends Mock implements DatadogFlags {}

class MockDatadogFlagsClient extends Mock implements DatadogFlagsClient {}

void main() {
  late MockDatadogSdk mockSdk;

  setUpAll(() {
    registerFallbackValue(const DatadogFlagsConfiguration());
    registerFallbackValue(FlagsEvaluationContext.empty);
  });

  setUp(() {
    mockSdk = MockDatadogSdk();
  });

  test('maps supported Datadog Flutter sites to Datadog Flags sites', () {
    expect(datadogFlagsSiteFor(DatadogSite.us1), DatadogFlagsSite.us1);
    expect(datadogFlagsSiteFor(DatadogSite.us3), DatadogFlagsSite.us3);
    expect(datadogFlagsSiteFor(DatadogSite.us5), DatadogFlagsSite.us5);
    expect(datadogFlagsSiteFor(DatadogSite.eu1), DatadogFlagsSite.eu1);
    expect(datadogFlagsSiteFor(DatadogSite.ap1), DatadogFlagsSite.ap1);
    expect(datadogFlagsSiteFor(DatadogSite.ap2), DatadogFlagsSite.ap2);
    expect(datadogFlagsSiteFor(DatadogSite.us1Fed), isNull);
  });

  test('creates flags configuration from Datadog SDK configuration', () async {
    DatadogFlagsConfiguration? capturedConfiguration;
    final flags = _mockFlags(onEnable: (configuration) {
      capturedConfiguration = configuration;
    });
    final configuration = DatadogConfiguration(
      clientToken: 'client-token',
      env: 'prod',
      site: DatadogSite.us3,
      service: 'shop',
      version: '1.2.3+4',
      rumConfiguration: DatadogRumConfiguration(applicationId: 'rum-app'),
    );
    when(() => mockSdk.configuration).thenReturn(configuration);

    final plugin = _plugin(mockSdk, flags: flags);

    plugin.initialize();
    await plugin.ready;

    final flagsConfiguration = capturedConfiguration!;
    final datadogConfig = flagsConfiguration.datadogConfig!;
    expect(datadogConfig.clientToken, 'client-token');
    expect(datadogConfig.env, 'prod');
    expect(datadogConfig.site, DatadogFlagsSite.us3);
    expect(datadogConfig.applicationId, 'rum-app');
    expect(datadogConfig.service, 'shop');
    expect(datadogConfig.version, '1.2.3-4');
  });

  test('keeps standalone flags configuration overrides', () async {
    DatadogFlagsConfiguration? capturedConfiguration;
    final flags = _mockFlags(onEnable: (configuration) {
      capturedConfiguration = configuration;
    });
    final date = DateTime.utc(2026);
    final flagsDatadogConfig = DatadogFlagsConfig(
      clientToken: 'flags-token',
      env: 'staging',
      site: DatadogFlagsSite.eu1,
      applicationId: 'flags-rum-app',
      service: 'flags-service',
      version: '9.9.9',
    );
    final configuration = DatadogConfiguration(
      clientToken: 'sdk-token',
      env: 'prod',
      site: DatadogSite.us1,
    );
    when(() => mockSdk.configuration).thenReturn(configuration);

    final plugin = _plugin(
      mockSdk,
      flags: flags,
      flagsConfiguration: DatadogFlagsConfiguration(
        customFlagsEndpoint: Uri.parse('https://flags.example.com'),
        customFlagsHeaders: const {'x-test': 'true'},
        customExposureEndpoint: Uri.parse('https://exposure.example.com'),
        trackExposures: false,
        customEvaluationEndpoint: Uri.parse('https://eval.example.com'),
        trackEvaluations: false,
        evaluationFlushInterval: const Duration(seconds: 2),
        datadogConfig: flagsDatadogConfig,
        dateProvider: () => date,
      ),
    );

    plugin.initialize();
    await plugin.ready;

    final flagsConfiguration = capturedConfiguration!;
    expect(flagsConfiguration.datadogConfig, same(flagsDatadogConfig));
    expect(
      flagsConfiguration.customFlagsEndpoint,
      Uri.parse('https://flags.example.com'),
    );
    expect(flagsConfiguration.customFlagsHeaders, const {'x-test': 'true'});
    expect(
      flagsConfiguration.customExposureEndpoint,
      Uri.parse('https://exposure.example.com'),
    );
    expect(flagsConfiguration.trackExposures, isFalse);
    expect(
      flagsConfiguration.customEvaluationEndpoint,
      Uri.parse('https://eval.example.com'),
    );
    expect(flagsConfiguration.trackEvaluations, isFalse);
    expect(
      flagsConfiguration.evaluationFlushInterval,
      const Duration(seconds: 2),
    );
    expect(flagsConfiguration.dateProvider(), date);
  });

  test('does not enable flags for unsupported Datadog sites', () async {
    final flags = _mockFlags();
    final configuration = DatadogConfiguration(
      clientToken: 'client-token',
      env: 'prod',
      site: DatadogSite.us1Fed,
    );
    when(() => mockSdk.configuration).thenReturn(configuration);

    final plugin = _plugin(mockSdk, flags: flags);

    plugin.initialize();
    await plugin.ready;

    verifyNever(
      () => flags.enable(
        configuration: any<DatadogFlagsConfiguration>(
          named: 'configuration',
        ),
      ),
    );
  });

  test('waits for plugin readiness before initializing client', () async {
    final delegate = _mockClient();
    final flags = _mockFlags(sharedClient: delegate);
    final configuration = DatadogConfiguration(
      clientToken: 'client-token',
      env: 'prod',
      site: DatadogSite.us1,
    );
    when(() => mockSdk.configuration).thenReturn(configuration);

    final plugin = _plugin(mockSdk, flags: flags);
    plugin.initialize();
    final client = plugin.sharedClient();
    const context = FlagsEvaluationContext(targetingKey: 'user-1');

    await client.initialize(context);

    verify(() => delegate.initialize(context)).called(1);
  });

  test('adds successful variants to RUM feature flag tracking', () async {
    final delegate = _mockClient();
    when(
      () => delegate.getBooleanDetails(
        key: any<String>(named: 'key'),
        defaultValue: any<bool>(named: 'defaultValue'),
      ),
    ).thenReturn(
      const FlagDetails(
        key: 'checkout.enabled',
        value: true,
        variant: 'on',
      ),
    );
    final rumEvaluations = <MapEntry<String, Object>>[];
    final client = DatadogFlutterFlagsClient(
      name: 'default',
      resolveDelegate: () async => delegate,
      addRumFeatureFlagEvaluation: (key, value) {
        rumEvaluations.add(MapEntry(key, value));
      },
    );

    await client.initialize(FlagsEvaluationContext.empty);
    final details = client.getBooleanDetails(
      key: 'checkout.enabled',
      defaultValue: false,
    );

    expect(details.value, isTrue);
    expect(rumEvaluations, hasLength(1));
    expect(rumEvaluations.single.key, 'checkout.enabled');
    expect(rumEvaluations.single.value, 'on');
  });

  test(
    'does not add failed evaluations to RUM feature flag tracking',
    () async {
      final delegate = _mockClient();
      when(
        () => delegate.getBooleanDetails(
          key: any<String>(named: 'key'),
          defaultValue: any<bool>(named: 'defaultValue'),
        ),
      ).thenReturn(
        const FlagDetails(
          key: 'checkout.enabled',
          value: false,
          error: FlagEvaluationError.flagNotFound,
        ),
      );
      final rumEvaluations = <MapEntry<String, Object>>[];
      final client = DatadogFlutterFlagsClient(
        name: 'default',
        resolveDelegate: () async => delegate,
        addRumFeatureFlagEvaluation: (key, value) {
          rumEvaluations.add(MapEntry(key, value));
        },
      );

      await client.initialize(FlagsEvaluationContext.empty);
      client.getBooleanDetails(key: 'checkout.enabled', defaultValue: false);

      expect(rumEvaluations, isEmpty);
    },
  );

  test(
    'accepts a null RUM integration callback',
    () async {
      final delegate = _mockClient();
      when(
        () => delegate.getBooleanDetails(
          key: any<String>(named: 'key'),
          defaultValue: any<bool>(named: 'defaultValue'),
        ),
      ).thenReturn(
        const FlagDetails(
          key: 'checkout.enabled',
          value: true,
          variant: 'on',
        ),
      );
      final client = DatadogFlutterFlagsClient(
        name: 'default',
        resolveDelegate: () async => delegate,
        addRumFeatureFlagEvaluation: null,
      );

      await client.initialize(FlagsEvaluationContext.empty);
      final details = client.getBooleanDetails(
        key: 'checkout.enabled',
        defaultValue: false,
      );

      expect(details.value, isTrue);
      expect(details.variant, 'on');
    },
  );

  test('returns providerNotReady before client initialization', () {
    final client = DatadogFlutterFlagsClient(
      name: 'default',
      resolveDelegate: () async => _mockClient(),
      addRumFeatureFlagEvaluation: null,
    );

    final details = client.getBooleanDetails(
      key: 'checkout.enabled',
      defaultValue: false,
    );

    expect(details.value, isFalse);
    expect(details.error, FlagEvaluationError.providerNotReady);
  });

  test('sdk extension returns configured flags plugin', () {
    final flags = _mockFlags();
    final plugin = _plugin(mockSdk, flags: flags);
    when(() => mockSdk.getPlugin<DatadogFlagsPlugin>()).thenReturn(plugin);

    expect(mockSdk.flags, same(plugin));
  });
}

DatadogFlagsPlugin _plugin(
  DatadogSdk sdk, {
  required DatadogFlags flags,
  DatadogFlagsConfiguration flagsConfiguration =
      const DatadogFlagsConfiguration(),
  bool rumIntegrationEnabled = true,
}) {
  return DatadogFlagsPlugin(
    sdk,
    flagsConfiguration: flagsConfiguration,
    rumIntegrationEnabled: rumIntegrationEnabled,
    flags: flags,
  );
}

MockDatadogFlags _mockFlags({
  void Function(DatadogFlagsConfiguration configuration)? onEnable,
  DatadogFlagsClient? sharedClient,
}) {
  final flags = MockDatadogFlags();
  when(
    () => flags.enable(
      configuration: any<DatadogFlagsConfiguration>(
        named: 'configuration',
      ),
    ),
  ).thenAnswer((invocation) async {
    onEnable?.call(
      invocation.namedArguments[#configuration] as DatadogFlagsConfiguration,
    );
  });
  when(() => flags.disable()).thenAnswer((_) async {});
  when(() => flags.reset()).thenAnswer((_) async {});
  if (sharedClient != null) {
    when(
      () => flags.sharedClient(name: any<String>(named: 'name')),
    ).thenReturn(sharedClient);
  }
  return flags;
}

MockDatadogFlagsClient _mockClient({
  String name = DatadogFlags.defaultClientName,
}) {
  final client = MockDatadogFlagsClient();
  when(() => client.name).thenReturn(name);
  when(
    () => client.initialize(any<FlagsEvaluationContext>()),
  ).thenAnswer((_) async {});
  when(() => client.reset()).thenAnswer((_) async {});
  when(() => client.shutdown()).thenAnswer((_) async {});
  return client;
}
