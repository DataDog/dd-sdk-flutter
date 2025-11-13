// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_flutter_plugin/src/rum/ddrum_noop_platform.dart';
import 'package:datadog_flutter_plugin/src/rum/ddrum_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDdRum extends Mock implements DatadogRum {}

class MockInternalLogger extends Mock implements InternalLogger {}

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockDatadogPlatform extends Mock implements DatadogSdkPlatform {}

class MockRumPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DdRumPlatform {}

class MockTimeProvider extends Mock implements DatadogTimeProvider {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(TracingId(BigInt.one));
  });

  // Because of the way we generate random numbers, add an integration test
  // to ensure that we don't break Web's ability to generate traceIds from Dart
  // libraries.
  testWidgets('test generating trace ids', (WidgetTester tester) async {
    final nowSeconds = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final traceId = TracingId.traceId();

    final traceIdString = traceId.asString(TracingIdRepresentation.hex);
    int traceSeconds = int.parse(traceIdString.substring(0, 8), radix: 16);
    expect(traceSeconds, closeTo(nowSeconds, 1));
    expect('00000000', traceIdString.substring(8, 16));
    expect(traceIdString.substring(16), isNot('0000000000000000'));
  });

  testWidgets('generateTracingContext generates proper bit values',
      (WidgetTester tester) async {
    final mockRum = MockDdRum();
    when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);

    final context = generateTracingContext(mockRum);

    expect(context.traceId.value.bitLength, lessThanOrEqualTo(128));
    expect(context.spanId.value.bitLength, lessThanOrEqualTo(63));
    expect(context.sampled, true);
  });

  // Check that our math works on web
  test('Sampling decisions are deterministic by traceId', () async {
    // Lots of extra setup to get a real version of RUM with a mock version of the Core
    final mockInternalLogger = MockInternalLogger();
    DdRumPlatform.instance = DdNoOpRumPlatform();

    final mockDatadogSdk = MockDatadogSdk();
    registerFallbackValue(DatadogSdk.instance);
    registerFallbackValue(DatadogRumConfiguration(applicationId: ''));
    registerFallbackValue(RumErrorSource.source);
    // ignore: invalid_use_of_internal_member
    when(() => mockDatadogSdk.internalLogger).thenReturn(mockInternalLogger);

    final mockDatadogPlatform = MockDatadogPlatform();
    when(() => mockDatadogPlatform.updateTelemetryConfiguration(any(), any()))
        .thenAnswer((_) => Future.value());
    when(() => mockDatadogSdk.platform).thenReturn(mockDatadogPlatform);

    final mockRumPlatform = MockRumPlatform();
    when(() => mockRumPlatform.setInternalViewAttribute(any(), any()))
        .thenAnswer((_) => Future.value());

    final inputs = <(BigInt, double, bool)>[
      (BigInt.parse('5577006791947779410'), 94.0509, true),
      (BigInt.parse('15352856648520921629'), 43.7714, true),
      (BigInt.parse('3916589616287113937'), 68.6823, true),
      (BigInt.parse('894385949183117216'), 30.0912, true),
      (BigInt.parse('12156940908066221323'), 46.889, true),
      (BigInt.parse('9828766684487745566'), 15.6519, false),
      (BigInt.parse('4751997750760398084'), 81.364, false),
      (BigInt.parse('11199607447739267382'), 38.0657, false),
      (BigInt.parse('6263450610539110790'), 21.8553, false),
      (BigInt.parse('1874068156324778273'), 36.0871, false),
    ];

    for (final (identifier, sampleRate, expected) in inputs) {
      final rumConfiguration = DatadogRumConfiguration(
        applicationId: 'applicationId',
        traceSampleRate: sampleRate,
        detectLongTasks: false,
      );
      final rum = await DatadogRum.enable(mockDatadogSdk, rumConfiguration);
      final tracingId = TracingId(identifier);
      bool shouldSample = rum!.shouldSampleTrace(null, tracingId);
      expect(shouldSample, expected);
    }
  });

  // Check that our math works on web
  test('Sampling decisions are deterministic by sessionId', () async {
    // Lots of extra setup to get a real version of RUM with a mock version of the Core
    final mockInternalLogger = MockInternalLogger();
    DdRumPlatform.instance = DdNoOpRumPlatform();

    final mockDatadogSdk = MockDatadogSdk();
    registerFallbackValue(DatadogSdk.instance);
    registerFallbackValue(DatadogRumConfiguration(applicationId: ''));
    registerFallbackValue(RumErrorSource.source);
    // ignore: invalid_use_of_internal_member
    when(() => mockDatadogSdk.internalLogger).thenReturn(mockInternalLogger);

    final mockDatadogPlatform = MockDatadogPlatform();
    when(() => mockDatadogPlatform.updateTelemetryConfiguration(any(), any()))
        .thenAnswer((_) => Future.value());
    when(() => mockDatadogSdk.platform).thenReturn(mockDatadogPlatform);

    final mockRumPlatform = MockRumPlatform();
    when(() => mockRumPlatform.setInternalViewAttribute(any(), any()))
        .thenAnswer((_) => Future.value());

    // The numbers used in the session UUID are the same numbers truncated to 48 bits,
    // which sometimes results in a different sampling decision. Created using this program:
    // https://go.dev/play/p/lUl2SiOHxfZ
    final inputs = <(String, BigInt, double, bool)>[
      (
        '11111111-2222-3333-4444-822107fcfd52',
        BigInt.parse('5577006791947779410'),
        94.050909,
        true
      ),
      (
        '11111111-2222-3333-4444-4dc76695721d',
        BigInt.parse('15352856648520921629'),
        43.771419,
        true
      ),
      (
        '11111111-2222-3333-4444-858149c6e2d1',
        BigInt.parse('3916589616287113937'),
        68.682307,
        true
      ),
      (
        '11111111-2222-3333-4444-cb397916001e',
        BigInt.parse('9828766684487745566'),
        15.651925,
        false
      ),
      (
        '11111111-2222-3333-4444-7f48392907a0',
        BigInt.parse('894385949183117216'),
        30.091186,
        true
      ),
      (
        '11111111-2222-3333-4444-7cc6f3875d04',
        BigInt.parse('4751997750760398084'),
        81.363996,
        true
      ),
      (
        '11111111-2222-3333-4444-ffa2ba517936',
        BigInt.parse('11199607447739267382'),
        38.065719,
        true
      ),
      (
        '11111111-2222-3333-4444-21587cb3ad0b',
        BigInt.parse('12156940908066221323'),
        46.888984,
        false
      ),
      (
        '11111111-2222-3333-4444-768b7c4e0b68',
        BigInt.parse('11833901312327420776'),
        29.310186,
        false
      ),
      (
        '11111111-2222-3333-4444-3f2525632186',
        BigInt.parse('6263450610539110790'),
        21.855305,
        false
      ),
    ];

    for (final (sessionId, identifier, sampleRate, expected) in inputs) {
      final rumConfiguration = DatadogRumConfiguration(
        applicationId: 'applicationId',
        traceSampleRate: sampleRate,
        detectLongTasks: false,
      );
      final rum = await DatadogRum.enable(mockDatadogSdk, rumConfiguration);
      final tracingId = TracingId(identifier);
      bool shouldSample = rum!.shouldSampleTrace(sessionId, tracingId);
      expect(shouldSample, expected);
    }
  });
}
