// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';
import 'dart:math';

import 'package:datadog_common_test/datadog_common_test.dart'
    hide DurationHelpers;
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_flutter_plugin/src/rum/ddrum_noop_platform.dart';
import 'package:datadog_flutter_plugin/src/rum/ddrum_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:uuid/v4.dart';

class MockInternalLogger extends Mock implements InternalLogger {}

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockDatadogPlatform extends Mock implements DatadogSdkPlatform {}

class MockRumPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DdRumPlatform {}

class MockTimeProvider extends Mock implements DatadogTimeProvider {}

void main() {
  const numSamples = 500;
  late MockInternalLogger mockInternalLogger;
  late MockDatadogSdk mockDatadogSdk;
  late MockDatadogPlatform mockDatadogPlatform;
  late MockRumPlatform mockRumPlatform;

  setUp(() {
    mockInternalLogger = MockInternalLogger();
    DdRumPlatform.instance = DdNoOpRumPlatform();

    mockDatadogSdk = MockDatadogSdk();
    registerFallbackValue(DatadogSdk.instance);
    registerFallbackValue(DatadogRumConfiguration(applicationId: ''));
    registerFallbackValue(RumErrorSource.source);
    when(() => mockDatadogSdk.internalLogger).thenReturn(mockInternalLogger);

    mockDatadogPlatform = MockDatadogPlatform();
    when(
      () => mockDatadogPlatform.updateTelemetryConfiguration(any(), any()),
    ).thenAnswer((_) => Future.value());
    when(() => mockDatadogSdk.platform).thenReturn(mockDatadogPlatform);

    mockRumPlatform = MockRumPlatform();
    when(
      () => mockRumPlatform.setInternalViewAttribute(any(), any()),
    ).thenAnswer((_) => Future.value());
  });

  test('RumResourceType parses simple mimeTypes from ContentType', () {
    final image = ContentType.parse('image/png');
    expect(resourceTypeFromContentType(image), RumResourceType.image);

    final video = ContentType.parse('video/mp4');
    expect(resourceTypeFromContentType(video), RumResourceType.media);

    final audio = ContentType.parse('audio/ogg');
    expect(resourceTypeFromContentType(audio), RumResourceType.media);

    final appJavascript = ContentType.parse('application/javascript');
    expect(resourceTypeFromContentType(appJavascript), RumResourceType.js);

    final textJavascript = ContentType.parse('text/javascript');
    expect(resourceTypeFromContentType(textJavascript), RumResourceType.js);

    final font = ContentType.parse('font/collection');
    expect(resourceTypeFromContentType(font), RumResourceType.font);

    final css = ContentType.parse('text/css');
    expect(resourceTypeFromContentType(css), RumResourceType.css);

    final other = ContentType.parse('application/octet-stream');
    expect(resourceTypeFromContentType(other), RumResourceType.native);
  });

  test('configuration has correct defaults', () {
    final configuration = DatadogRumConfiguration(applicationId: 'fake-app-id');

    expect(configuration.sessionSamplingRate, 100.0);
    expect(configuration.traceSampleRate, 20.0);
    expect(configuration.traceContextInjection, TraceContextInjection.sampled);
    expect(configuration.detectLongTasks, true);
    expect(configuration.longTaskThreshold, 0.1);
    expect(configuration.vitalUpdateFrequency, VitalsFrequency.average);
    expect(configuration.reportFlutterPerformance, false);
    expect(configuration.trackNonFatalAnrs, isNull);
    expect(configuration.appHangThreshold, isNull);
    expect(configuration.trackAnonymousUser, true);
    expect(configuration.initialResourceThreshold, 0.1);
  });

  test('configuration is encoded correctly', () {
    final applicationId = randomString();
    final detectLongTasks = randomBool();
    final trackFrustrations = randomBool();
    final vitalUpdateFrequency = VitalsFrequency.values.randomElement();
    final customEndpoint = randomString();
    final configuration = DatadogRumConfiguration(
      applicationId: applicationId,
      sessionSamplingRate: 12.0,
      traceSampleRate: 50.2,
      detectLongTasks: detectLongTasks,
      longTaskThreshold: 0.3,
      trackFrustrations: trackFrustrations,
      vitalUpdateFrequency: vitalUpdateFrequency,
      trackNonFatalAnrs: false,
      appHangThreshold: 0.332,
      trackAnonymousUser: false,
      trackBackgroundEvents: true,
      initialResourceThreshold: 1.23,
      customEndpoint: customEndpoint,
    );

    final encoded = configuration.encode();
    expect(encoded['applicationId'], applicationId);
    expect(encoded['sessionSampleRate'], 12.0);
    expect(encoded['detectLongTasks'], detectLongTasks);
    expect(encoded['longTaskThreshold'], 0.3);
    expect(encoded['trackFrustrations'], trackFrustrations);
    expect(encoded['vitalsUpdateFrequency'], vitalUpdateFrequency.toString());
    expect(encoded['trackNonFatalAnrs'], false);
    expect(encoded['trackAnonymousUser'], false);
    expect(encoded['trackBackgroundEvents'], true);
    expect(encoded['appHangThreshold'], 0.332);
    expect(encoded['customEndpoint'], customEndpoint);
    expect(encoded['initialResourceThreshold'], 1.23);
  });

  test('configuration with mapper sets attach*Mapper', () {
    final configuration = DatadogRumConfiguration(
      applicationId: 'fake-application-id',
      viewEventMapper: (event) => event,
      actionEventMapper: (event) => event,
      resourceEventMapper: (event) => event,
      errorEventMapper: (event) => event,
      longTaskEventMapper: (event) => event,
    );

    final encoded = configuration.encode();
    expect(encoded['attachViewEventMapper'], isTrue);
    expect(encoded['attachActionEventMapper'], isTrue);
    expect(encoded['attachResourceEventMapper'], isTrue);
    expect(encoded['attachErrorEventMapper'], isTrue);
    expect(encoded['attachLongTaskEventMapper'], isTrue);
  });

  test('Session sampling rate is clamped to 0..100', () {
    final lowConfiguration = DatadogRumConfiguration(
      applicationId: 'applicationId',
      sessionSamplingRate: -12.3,
    );

    final highConfiguration = DatadogRumConfiguration(
      applicationId: 'applicationId',
      sessionSamplingRate: 137.2,
    );

    expect(lowConfiguration.sessionSamplingRate, equals(0.0));
    expect(highConfiguration.sessionSamplingRate, equals(100.0));
  });

  test('Tracing sampling rate is clamped to 0..100', () {
    final lowConfiguration = DatadogRumConfiguration(
      applicationId: 'applicationId',
      traceSampleRate: -12.3,
    );

    final highConfiguration = DatadogRumConfiguration(
      applicationId: 'applicationId',
      traceSampleRate: 137.2,
    );

    expect(lowConfiguration.traceSampleRate, equals(0.0));
    expect(highConfiguration.traceSampleRate, equals(100.0));
  });

  test('Setting trace sample rate to 100 should always sample', () async {
    final rumConfiguration = DatadogRumConfiguration(
      applicationId: 'applicationId',
      traceSampleRate: 100,
      detectLongTasks: false,
    );
    final rum = await DatadogRum.enable(mockDatadogSdk, rumConfiguration);

    for (int i = 0; i < 10; ++i) {
      final trace = TracingId.traceId();
      final sessionId = UuidV4().toString();
      expect(rum!.shouldSampleTrace(sessionId, trace), isTrue);
    }
  });

  test('Setting trace sample rate to 0 should never sample', () async {
    final rumConfiguration = DatadogRumConfiguration(
      applicationId: 'applicationId',
      traceSampleRate: 0,
      detectLongTasks: false,
    );
    final rum = await DatadogRum.enable(mockDatadogSdk, rumConfiguration);

    for (int i = 0; i < 10; ++i) {
      final trace = TracingId.traceId();
      final sessionId = UuidV4().toString();
      expect(rum!.shouldSampleTrace(sessionId, trace), isFalse);
    }
  });

  test('Low sampling rate returns samples less often', () async {
    final rumConfiguration = DatadogRumConfiguration(
      applicationId: 'applicationId',
      traceSampleRate: 23,
      detectLongTasks: false,
    );
    final rum = await DatadogRum.enable(mockDatadogSdk, rumConfiguration);

    var sampleCount = 0;
    var noSampleCount = 0;
    for (int i = 0; i < numSamples; ++i) {
      final trace = TracingId.traceId();
      final sessionId = UuidV4().toString();
      if (rum!.shouldSampleTrace(sessionId, trace)) {
        sampleCount++;
      } else {
        noSampleCount++;
      }
    }

    expect(noSampleCount, greaterThanOrEqualTo(sampleCount));
    expect(sampleCount, greaterThanOrEqualTo(1));
  });

  test('High sampling rate returns samples more often', () async {
    final rumConfiguration = DatadogRumConfiguration(
      applicationId: 'applicationId',
      traceSampleRate: 85,
      detectLongTasks: false,
    );
    final rum = await DatadogRum.enable(mockDatadogSdk, rumConfiguration);

    var sampleCount = 0;
    var noSampleCount = 0;
    for (int i = 0; i < numSamples; ++i) {
      final trace = TracingId.traceId();
      final sessionId = UuidV4().toString();
      if (rum!.shouldSampleTrace(sessionId, trace)) {
        sampleCount++;
      } else {
        noSampleCount++;
      }
    }

    expect(sampleCount, greaterThanOrEqualTo(noSampleCount));
    expect(noSampleCount, greaterThanOrEqualTo(1));
  });

  test('Sampling decisions are deterministic for traceId', () async {
    // Generated using the dd-trace-go implementation with the following program: https://go.dev/play/p/CUrDJtze8E_e
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

  test('Sampling decisions are deterministic for sessionId', () async {
    // The numbers used in the session UUID are the same numbers truncated to 48 bits,
    // which sometimes results in a different sampling decision. Created using this program:
    // https://go.dev/play/p/lUl2SiOHxfZ
    final inputs = <(String, BigInt, double, bool)>[
      (
        '11111111-2222-3333-4444-822107fcfd52',
        BigInt.parse('5577006791947779410'),
        94.050909,
        true,
      ),
      (
        '11111111-2222-3333-4444-4dc76695721d',
        BigInt.parse('15352856648520921629'),
        43.771419,
        true,
      ),
      (
        '11111111-2222-3333-4444-858149c6e2d1',
        BigInt.parse('3916589616287113937'),
        68.682307,
        true,
      ),
      (
        '11111111-2222-3333-4444-cb397916001e',
        BigInt.parse('9828766684487745566'),
        15.651925,
        false,
      ),
      (
        '11111111-2222-3333-4444-7f48392907a0',
        BigInt.parse('894385949183117216'),
        30.091186,
        true,
      ),
      (
        '11111111-2222-3333-4444-7cc6f3875d04',
        BigInt.parse('4751997750760398084'),
        81.363996,
        true,
      ),
      (
        '11111111-2222-3333-4444-ffa2ba517936',
        BigInt.parse('11199607447739267382'),
        38.065719,
        true,
      ),
      (
        '11111111-2222-3333-4444-21587cb3ad0b',
        BigInt.parse('12156940908066221323'),
        46.888984,
        false,
      ),
      (
        '11111111-2222-3333-4444-768b7c4e0b68',
        BigInt.parse('11833901312327420776'),
        29.310186,
        false,
      ),
      (
        '11111111-2222-3333-4444-3f2525632186',
        BigInt.parse('6263450610539110790'),
        21.855305,
        false,
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

  test('getCurrentSessionId returns id from platform', () async {
    // Given
    final fakeSessionId = randomString(length: 12);
    DdRumPlatform.instance = mockRumPlatform;
    when(
      () => mockRumPlatform.enable(any(), any()),
    ).thenAnswer((_) => Future.value());
    when(
      () => mockRumPlatform.getCurrentSessionId(),
    ).thenAnswer((_) => Future.value(fakeSessionId));
    final rum = await DatadogRum.enable(
      mockDatadogSdk,
      DatadogRumConfiguration(
        applicationId: 'applicationId',
        detectLongTasks: false,
      ),
    );

    // When
    var sessionId = await rum!.getCurrentSessionId();

    // Then
    expect(sessionId, fakeSessionId);
  });

  test('addAttribute with null calls remove attribute instead', () async {
    // Given
    DdRumPlatform.instance = mockRumPlatform;
    when(
      () => mockRumPlatform.enable(any(), any()),
    ).thenAnswer((_) => Future.value());
    when(
      () => mockRumPlatform.removeAttribute(any()),
    ).thenAnswer((_) => Future.value());
    final rum = await DatadogRum.enable(
      mockDatadogSdk,
      DatadogRumConfiguration(
        applicationId: 'applicationId',
        detectLongTasks: false,
      ),
    );

    // when
    rum!.addAttribute('attribute-key', null);

    // Then
    verify(() => mockRumPlatform.removeAttribute('attribute-key'));
    verifyNever(() => mockRumPlatform.addAttribute(any(), any()));
  });

  test(
    'addError does not forward to platform on MissingPluginException',
    () async {
      // Given
      DdRumPlatform.instance = mockRumPlatform;
      when(
        () => mockRumPlatform.enable(any(), any()),
      ).thenAnswer((_) => Future.value());
      when(
        () => mockRumPlatform.removeAttribute(any()),
      ).thenAnswer((_) => Future.value());
      final rum = await DatadogRum.enable(
        mockDatadogSdk,
        DatadogRumConfiguration(
          applicationId: 'applicationId',
          detectLongTasks: false,
        ),
      );

      // when
      final exception = MissingPluginException(
        'No implementation found for method addError on channel datadog_sdk_flutter.rum',
      );
      rum!.addError(exception, RumErrorSource.source);

      // Then
      verifyNever(
        () => rum.addError(
          any(),
          any(),
          stackTrace: any(),
          errorType: any(),
          attributes: any(),
        ),
      );
    },
  );

  test(
    'addErrorInfo does not forward to platform on MissingPluginException',
    () async {
      // Given
      DdRumPlatform.instance = mockRumPlatform;
      when(
        () => mockRumPlatform.enable(any(), any()),
      ).thenAnswer((_) => Future.value());
      when(
        () => mockRumPlatform.removeAttribute(any()),
      ).thenAnswer((_) => Future.value());
      final rum = await DatadogRum.enable(
        mockDatadogSdk,
        DatadogRumConfiguration(
          applicationId: 'applicationId',
          detectLongTasks: false,
        ),
      );

      // when
      final exception = MissingPluginException(
        'No implementation found for method addError on channel datadog_sdk_flutter.rum',
      );
      rum!.addErrorInfo(exception.toString(), RumErrorSource.source);

      // Then
      verifyNever(
        () => rum.addError(
          any(),
          any(),
          stackTrace: any(),
          errorType: any(),
          attributes: any(),
        ),
      );
    },
  );

  group('markViewFirstBuildComplete', () {
    late DatadogRum rum;
    final random = Random();
    final mockTimeProvider = MockTimeProvider();

    setUp(() async {
      DdRumPlatform.instance = mockRumPlatform;
      final rumConfiguration = DatadogRumConfiguration(
        applicationId: 'applicationId',
        traceSampleRate: 23,
        detectLongTasks: false,
      );

      when(
        () => mockRumPlatform.enable(any(), any()),
      ).thenAnswer((_) => Future.value());
      when(
        () => mockRumPlatform.startView(any(), any(), any(), any()),
      ).thenAnswer((_) => Future.value());
      when(
        () => mockRumPlatform.stopView(any(), any(), any()),
      ).thenAnswer((_) => Future.value());
      when(
        () => mockRumPlatform.addAttribute(any(), any()),
      ).thenAnswer((_) => Future.value());

      rum = (await DatadogRum.enable(mockDatadogSdk, rumConfiguration))!;
      rum.timeProvider = mockTimeProvider;
    });

    test(
      'markViewFirstBuildComplete adds ns timestamp as view attribute',
      testOn: 'vm',
      () {
        final startTime = DateTime.now();
        final duration = random.nextInt(1 << 32);
        final timeAnswers = [
          startTime,
          startTime.add(Duration(microseconds: duration)),
        ];
        when(
          () => mockTimeProvider.now(),
        ).thenAnswer((_) => timeAnswers.removeAt(0));
        rum.startView('test_view');
        rum.markViewFirstBuildComplete('test_view');

        verify(
          () => mockRumPlatform.setInternalViewAttribute(
            '_dd.performance.first_build_complete',
            duration * 1000,
          ),
        );
      },
    );

    test(
      'markViewFirstBuildComplete adds no attribute if view not started',
      () {
        rum.markViewFirstBuildComplete('test_view');

        verifyNever(
          () => mockRumPlatform.setInternalViewAttribute(
            '_dd.performance.first_build_complete',
            any(),
          ),
        );
      },
    );

    test(
      'markViewFirstBuildComplete adds no attribute if different view started',
      () {
        when(() => mockTimeProvider.now()).thenAnswer((_) => DateTime.now());
        rum.startView('test_view');
        rum.markViewFirstBuildComplete('second_view');

        verifyNever(
          () => mockRumPlatform.setInternalViewAttribute(
            '_dd.performance.first_build_complete',
            any(),
          ),
        );
      },
    );

    test('markViewFirstBuildComplete adds no attribute if view stopped', () {
      when(() => mockTimeProvider.now()).thenAnswer((_) => DateTime.now());
      rum.startView('test_view');
      rum.stopView('test_view');
      rum.markViewFirstBuildComplete('test_view');

      verifyNever(
        () => mockRumPlatform.setInternalViewAttribute(
          '_dd.performance.first_build_complete',
          any(),
        ),
      );
    });
  });

  group('interaction to next view', () {
    late DatadogRum rum;
    final random = Random();
    final mockTimeProvider = MockTimeProvider();

    setUp(() async {
      DdRumPlatform.instance = mockRumPlatform;
      final rumConfiguration = DatadogRumConfiguration(
        applicationId: 'applicationId',
        traceSampleRate: 23,
        detectLongTasks: false,
      );

      registerFallbackValue(RumActionType.custom);

      when(
        () => mockRumPlatform.enable(any(), any()),
      ).thenAnswer((_) => Future.value());
      when(
        () => mockRumPlatform.startView(any(), any(), any(), any()),
      ).thenAnswer((_) => Future.value());
      when(
        () => mockRumPlatform.stopView(any(), any(), any()),
      ).thenAnswer((_) => Future.value());
      when(
        () => mockRumPlatform.addAction(any(), any(), any(), any()),
      ).thenAnswer((_) => Future.value());
      when(
        () => mockRumPlatform.addAttribute(any(), any()),
      ).thenAnswer((_) => Future.value());

      rum = (await DatadogRum.enable(mockDatadogSdk, rumConfiguration))!;
      rum.timeProvider = mockTimeProvider;
    });

    test('markViewFirstBuildComplete sets inv attribute', () {
      // Given
      final startTime = DateTime.now();
      final actionTime = startTime.add(Duration(seconds: 1));
      final startTime2 = actionTime.add(Duration(milliseconds: 10));
      final fbcTime = startTime2.add(
        Duration(microseconds: random.nextInt(1 << 8)),
      );
      final timeAnswers = [startTime, actionTime, startTime2, fbcTime];
      when(
        () => mockTimeProvider.now(),
      ).thenAnswer((_) => timeAnswers.removeAt(0));

      // When
      rum.startView('test_view');
      rum.addAction(RumActionType.tap, 'Test Action');
      rum.startView('test_view_2');
      rum.markViewFirstBuildComplete('test_view_2');

      verify(
        () => mockRumPlatform.setInternalViewAttribute(
          '_dd.view.custom_inv_value',
          (fbcTime.difference(actionTime)).inNanoseconds,
        ),
      );
    });

    test(
      'markViewFirstBuildComplete does not set inv attribute if missing',
      () {
        // Given
        final startTime = DateTime.now();
        final startTime2 = startTime.add(Duration(seconds: 10));
        final fbcTime = startTime2.add(
          Duration(microseconds: random.nextInt(1 << 8)),
        );
        final timeAnswers = [startTime, startTime2, fbcTime];
        when(
          () => mockTimeProvider.now(),
        ).thenAnswer((_) => timeAnswers.removeAt(0));

        // When
        rum.startView('test_view');
        rum.startView('test_view_2');
        rum.markViewFirstBuildComplete('test_view_2');

        verifyNever(
          () => mockRumPlatform.setInternalViewAttribute(
            '_dd.view.custom_inv_value',
            any(),
          ),
        );
      },
    );
  });
}
