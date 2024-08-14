// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_flutter_plugin/src/rum/ddrum_noop_platform.dart';
import 'package:datadog_flutter_plugin/src/rum/ddrum_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockInternalLogger extends Mock implements InternalLogger {}

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockDatadogPlatform extends Mock implements DatadogSdkPlatform {}

class MockRumPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DdRumPlatform {}

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
    when(() => mockDatadogPlatform.updateTelemetryConfiguration(any(), any()))
        .thenAnswer((_) => Future.value());

    when(() => mockDatadogSdk.platform).thenReturn(mockDatadogPlatform);

    mockRumPlatform = MockRumPlatform();
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
    expect(encoded['appHangThreshold'], 0.332);
    expect(encoded['customEndpoint'], customEndpoint);
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
      expect(rum!.shouldSampleTrace(), isTrue);
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
      expect(rum!.shouldSampleTrace(), isFalse);
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
      if (rum!.shouldSampleTrace()) {
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
      if (rum!.shouldSampleTrace()) {
        sampleCount++;
      } else {
        noSampleCount++;
      }
    }

    expect(sampleCount, greaterThanOrEqualTo(noSampleCount));
    expect(noSampleCount, greaterThanOrEqualTo(1));
  });

  test('getCurrentSessionId returns id from platform', () async {
    // Given
    final fakeSessionId = randomString(length: 12);
    DdRumPlatform.instance = mockRumPlatform;
    when(() => mockRumPlatform.enable(any(), any()))
        .thenAnswer((_) => Future.value());
    when(() => mockRumPlatform.getCurrentSessionId())
        .thenAnswer((_) => Future.value(fakeSessionId));
    final rum = await DatadogRum.enable(
        mockDatadogSdk,
        DatadogRumConfiguration(
          applicationId: 'applicationId',
          detectLongTasks: false,
        ));

    // When
    var sessionId = await rum!.getCurrentSessionId();

    // Then
    expect(sessionId, fakeSessionId);
  });

  test('addAttribute with null calls remove attribute instead', () async {
    // Given
    DdRumPlatform.instance = mockRumPlatform;
    when(() => mockRumPlatform.enable(any(), any()))
        .thenAnswer((_) => Future.value());
    when(() => mockRumPlatform.removeAttribute(any()))
        .thenAnswer((_) => Future.value());
    final rum = await DatadogRum.enable(
        mockDatadogSdk,
        DatadogRumConfiguration(
          applicationId: 'applicationId',
          detectLongTasks: false,
        ));

    // when
    rum!.addAttribute('attribute-key', null);

    // Then
    verify(() => mockRumPlatform.removeAttribute('attribute-key'));
    verifyNever(() => mockRumPlatform.addAttribute(any(), any()));
  });

  test('addError does not forward to platform on MissingPluginException',
      () async {
    // Given
    DdRumPlatform.instance = mockRumPlatform;
    when(() => mockRumPlatform.enable(any(), any()))
        .thenAnswer((_) => Future.value());
    when(() => mockRumPlatform.removeAttribute(any()))
        .thenAnswer((_) => Future.value());
    final rum = await DatadogRum.enable(
        mockDatadogSdk,
        DatadogRumConfiguration(
          applicationId: 'applicationId',
          detectLongTasks: false,
        ));

    // when
    final exception = MissingPluginException(
        'No implementation found for method addError on channel datadog_sdk_flutter.rum');
    rum!.addError(exception, RumErrorSource.source);

    // Then
    verifyNever(() => rum.addError(any(), any(),
        stackTrace: any(), errorType: any(), attributes: any()));
  });

  test('addErrorInfo does not forward to platform on MissingPluginException',
      () async {
    // Given
    DdRumPlatform.instance = mockRumPlatform;
    when(() => mockRumPlatform.enable(any(), any()))
        .thenAnswer((_) => Future.value());
    when(() => mockRumPlatform.removeAttribute(any()))
        .thenAnswer((_) => Future.value());
    final rum = await DatadogRum.enable(
        mockDatadogSdk,
        DatadogRumConfiguration(
          applicationId: 'applicationId',
          detectLongTasks: false,
        ));

    // when
    final exception = MissingPluginException(
        'No implementation found for method addError on channel datadog_sdk_flutter.rum');
    rum!.addErrorInfo(exception.toString(), RumErrorSource.source);

    // Then
    verifyNever(() => rum.addError(any(), any(),
        stackTrace: any(), errorType: any(), attributes: any()));
  });
}
