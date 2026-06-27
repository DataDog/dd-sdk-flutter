// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockInternalLogger extends Mock implements InternalLogger {}

class CapturingDatadogFlags extends DatadogFlags {
  DatadogFlagsConfiguration? configuration;
  bool resetCalled = false;
  bool disableCalled = false;

  final Map<String, DatadogFlagsClient> clients = {};

  @override
  Future<void> enable({
    DatadogFlagsConfiguration configuration = const DatadogFlagsConfiguration(),
  }) async {
    this.configuration = configuration;
  }

  @override
  DatadogFlagsClient sharedClient({
    String name = DatadogFlags.defaultClientName,
  }) {
    return clients.putIfAbsent(name, () => FakeDatadogFlagsClient(name));
  }

  @override
  Future<void> reset() async {
    resetCalled = true;
  }

  @override
  Future<void> disable() async {
    disableCalled = true;
  }
}

class FakeDatadogFlagsClient implements DatadogFlagsClient {
  @override
  final String name;

  FlagsEvaluationContext? initializedContext;
  bool resetCalled = false;
  bool shutdownCalled = false;

  FlagDetails<bool>? booleanDetails;
  FlagDetails<String>? stringDetails;
  FlagDetails<int>? integerDetails;
  FlagDetails<double>? doubleDetails;
  FlagDetails<Object?>? objectDetails;

  FakeDatadogFlagsClient(this.name);

  @override
  Future<void> initialize(FlagsEvaluationContext context) async {
    initializedContext = context;
  }

  @override
  FlagDetails<bool> getBooleanDetails({
    required String key,
    required bool defaultValue,
  }) {
    return booleanDetails ??
        FlagDetails(key: key, value: defaultValue, variant: 'boolean-variant');
  }

  @override
  FlagDetails<String> getStringDetails({
    required String key,
    required String defaultValue,
  }) {
    return stringDetails ??
        FlagDetails(key: key, value: defaultValue, variant: 'string-variant');
  }

  @override
  FlagDetails<int> getIntegerDetails({
    required String key,
    required int defaultValue,
  }) {
    return integerDetails ??
        FlagDetails(key: key, value: defaultValue, variant: 'integer-variant');
  }

  @override
  FlagDetails<double> getDoubleDetails({
    required String key,
    required double defaultValue,
  }) {
    return doubleDetails ??
        FlagDetails(key: key, value: defaultValue, variant: 'double-variant');
  }

  @override
  FlagDetails<Object?> getObjectDetails({
    required String key,
    required Object? defaultValue,
  }) {
    return objectDetails ??
        FlagDetails(key: key, value: defaultValue, variant: 'object-variant');
  }

  @override
  Future<void> reset() async {
    resetCalled = true;
  }

  @override
  Future<void> shutdown() async {
    shutdownCalled = true;
  }
}

void main() {
  late MockDatadogSdk mockSdk;
  late MockInternalLogger mockLogger;

  setUp(() {
    mockSdk = MockDatadogSdk();
    mockLogger = MockInternalLogger();
    when(() => mockSdk.internalLogger).thenReturn(mockLogger);
  });

  test('creates flags configuration from Datadog SDK configuration', () async {
    final flags = CapturingDatadogFlags();
    final configuration = DatadogConfiguration(
      clientToken: 'client-token',
      env: 'prod',
      site: DatadogSite.us3,
      service: 'shop',
      version: '1.2.3+4',
      rumConfiguration: DatadogRumConfiguration(applicationId: 'rum-app'),
    );
    when(() => mockSdk.configuration).thenReturn(configuration);

    final plugin = DatadogFlagsPlugin(mockSdk, flags: flags);

    plugin.initialize();
    await plugin.ready;

    final flagsConfiguration = flags.configuration!;
    final datadogConfig = flagsConfiguration.datadogConfig!;
    expect(datadogConfig.clientToken, 'client-token');
    expect(datadogConfig.env, 'prod');
    expect(datadogConfig.site, DatadogFlagsSite.us3);
    expect(datadogConfig.applicationId, 'rum-app');
    expect(datadogConfig.service, 'shop');
    expect(datadogConfig.version, '1.2.3-4');
  });

  test('keeps standalone flags configuration overrides', () async {
    final flags = CapturingDatadogFlags();
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

    final plugin = DatadogFlagsPlugin(
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

    final flagsConfiguration = flags.configuration!;
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
    final flags = CapturingDatadogFlags();
    final configuration = DatadogConfiguration(
      clientToken: 'client-token',
      env: 'prod',
      site: DatadogSite.us1Fed,
    );
    when(() => mockSdk.configuration).thenReturn(configuration);
    when(() => mockLogger.warn(any())).thenReturn(null);

    final plugin = DatadogFlagsPlugin(mockSdk, flags: flags);

    plugin.initialize();
    await plugin.ready;

    expect(flags.configuration, isNull);
    verify(
      () =>
          mockLogger.warn('Datadog Flags does not support DatadogSite.us1Fed.'),
    );
  });

  test('waits for plugin readiness before initializing client', () async {
    final flags = CapturingDatadogFlags();
    final configuration = DatadogConfiguration(
      clientToken: 'client-token',
      env: 'prod',
      site: DatadogSite.us1,
    );
    when(() => mockSdk.configuration).thenReturn(configuration);

    final plugin = DatadogFlagsPlugin(mockSdk, flags: flags);
    plugin.initialize();
    final client = plugin.sharedClient();
    const context = FlagsEvaluationContext(targetingKey: 'user-1');

    await client.initialize(context);

    final delegate = flags.clients[DatadogFlags.defaultClientName]!
        as FakeDatadogFlagsClient;
    expect(delegate.initializedContext, context);
  });

  test('adds successful variants to RUM feature flag tracking', () async {
    final delegate = FakeDatadogFlagsClient('default')
      ..booleanDetails = const FlagDetails(
        key: 'checkout.enabled',
        value: true,
        variant: 'on',
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
      final delegate = FakeDatadogFlagsClient('default')
        ..booleanDetails = const FlagDetails(
          key: 'checkout.enabled',
          value: false,
          error: FlagEvaluationError.flagNotFound,
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
    'does not add evaluations to RUM when integration is disabled',
    () async {
      final delegate = FakeDatadogFlagsClient('default');
      final rumEvaluations = <MapEntry<String, Object>>[];
      final client = DatadogFlutterFlagsClient(
        name: 'default',
        resolveDelegate: () async => delegate,
        addRumFeatureFlagEvaluation: (key, value) {
          rumEvaluations.add(MapEntry(key, value));
        },
        rumIntegrationEnabled: false,
      );

      await client.initialize(FlagsEvaluationContext.empty);
      client.getBooleanDetails(key: 'checkout.enabled', defaultValue: false);

      expect(rumEvaluations, isEmpty);
    },
  );

  test('returns providerNotReady before client initialization', () {
    final client = DatadogFlutterFlagsClient(
      name: 'default',
      resolveDelegate: () async => FakeDatadogFlagsClient('default'),
      addRumFeatureFlagEvaluation: (_, __) {},
    );

    final details = client.getBooleanDetails(
      key: 'checkout.enabled',
      defaultValue: false,
    );

    expect(details.value, isFalse);
    expect(details.error, FlagEvaluationError.providerNotReady);
  });

  test('sdk extension returns configured flags plugin', () {
    final flags = CapturingDatadogFlags();
    final plugin = DatadogFlagsPlugin(mockSdk, flags: flags);
    when(() => mockSdk.getPlugin<DatadogFlagsPlugin>()).thenReturn(plugin);

    expect(mockSdk.flags, same(plugin));
  });
}
