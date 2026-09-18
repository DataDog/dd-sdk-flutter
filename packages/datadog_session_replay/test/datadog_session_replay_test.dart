// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_noop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockInternalLogger extends Mock implements InternalLogger {}

class MockDatadogSessionReplayPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DatadogSessionReplayPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final DatadogSessionReplayPlatform initialPlatform =
      DatadogSessionReplayPlatform.instance;

  test('$DatadogSessionReplayPlatformNoop is the default instance', () {
    expect(initialPlatform, isInstanceOf<DatadogSessionReplayPlatformNoop>());
  });

  test('DatadogSessionReplayConfiguration default fontFamilyTransform is none',
      () {
    final c = DatadogSessionReplayConfiguration(replaySampleRate: 100.0);
    expect(c.fontFamilyTransform.strategy, FontFamilyStrategy.none);
    expect(c.fontFamilyTransform.rules, isEmpty);
  });

  test('DatadogSessionReplayConfiguration default imageDownscaling is disabled',
      () {
    final c = DatadogSessionReplayConfiguration(replaySampleRate: 100.0);
    expect(c.imageDownscaling, ImageDownscaling.disabled);
  });

  group('DatadogSessionReplay', () {
    final mockPlatform = MockDatadogSessionReplayPlatform();
    final mockInternalLogger = MockInternalLogger();

    setUp(() {
      // Replace the default platform with the mock one
      DatadogSessionReplayPlatform.instance = mockPlatform;

      registerFallbackValue(
        DatadogSessionReplayConfiguration(replaySampleRate: 100),
      );
    });

    test('.init() calls enable on platform', () {
      // Given
      when(
        () => mockPlatform.enable(any(), any()),
      ).thenAnswer((_) => Future.value(false));

      // When
      final config = DatadogSessionReplayConfiguration(replaySampleRate: 100.0);
      DatadogSessionReplay.init(config, mockInternalLogger);

      // Then
      verify(() => mockPlatform.enable(config, any()));
    });

    // TODO: Test setup of Recorder / Processor?

    group('start/stop recording', () {
      // Given
      final defaultConfig = DatadogSessionReplayConfiguration(
        replaySampleRate: 100.0,
        startRecordingImmediately: false,
      );

      setUp(() {
        // Returning false avoids spawning the processor isolate in tests
        when(
          () => mockPlatform.enable(any(), any()),
        ).thenAnswer((_) => Future.value(false));
      });

      tearDown(() {
        DatadogSessionReplay.resetInstance();
      });

      test('is not recording after init', () async {
        // When
        final sr =
            await DatadogSessionReplay.init(defaultConfig, mockInternalLogger);

        // Then
        expect(sr.isCapturing, false);
      });

      test('startRecording() sets isCapturing to true', () async {
        // Given
        final sr =
            await DatadogSessionReplay.init(defaultConfig, mockInternalLogger);

        // When
        sr.startRecording();

        // Then
        expect(sr.isCapturing, true);
      });

      test('stopRecording() sets isCapturing to false', () async {
        // Given
        final sr =
            await DatadogSessionReplay.init(defaultConfig, mockInternalLogger);
        sr.startRecording();

        // When
        sr.stopRecording();

        // Then
        expect(sr.isCapturing, false);
      });

      test('calling startRecording() keeps the recording active', () async {
        // Given
        final sr =
            await DatadogSessionReplay.init(defaultConfig, mockInternalLogger);
        sr.startRecording();

        // When
        sr.startRecording();

        // Then
        expect(sr.isCapturing, true);
      });

      test('start/stop/start cycle works', () async {
        // Given
        final sr =
            await DatadogSessionReplay.init(defaultConfig, mockInternalLogger);

        // When
        sr.startRecording();
        sr.stopRecording();
        sr.startRecording();

        // Then
        expect(sr.isCapturing, true);
      });

      test('stopRecording() is safe when not recording', () async {
        // Given
        final sr =
            await DatadogSessionReplay.init(defaultConfig, mockInternalLogger);

        // When / Then
        expect(() => sr.stopRecording(), returnsNormally);
        expect(sr.isCapturing, false);
      });

      test(
          'isCapturing is true after init with startRecordingImmediately: true',
          () async {
        // Given — enable() must return true so _start() reaches startRecording()
        when(() => mockPlatform.enable(any(), any()))
            .thenAnswer((_) => Future.value(true));
        when(() => mockPlatform.isolateToken).thenReturn(null);

        final config = DatadogSessionReplayConfiguration(
          replaySampleRate: 100.0,
          startRecordingImmediately: true,
        );

        // When
        final sr = await DatadogSessionReplay.init(config, mockInternalLogger);

        // Then
        expect(sr.isCapturing, true);
      });
    });
  });
}
