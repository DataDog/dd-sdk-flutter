// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
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
    expect(initialPlatform, isA<DatadogSessionReplayPlatformNoop>());
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

    tearDown(() {
      DatadogSessionReplay.resetForTest();
      DatadogSessionReplayPlatform.instance = initialPlatform;
    });

    test('.init() calls enable on platform', () async {
      // Given
      when(
        () => mockPlatform.enable(any(), any()),
      ).thenAnswer((_) => Future.value(false));

      // When
      final config = DatadogSessionReplayConfiguration(replaySampleRate: 100.0);
      await DatadogSessionReplay.init(config, mockInternalLogger);

      // Then
      verify(() => mockPlatform.enable(config, any()));
    });

    test('startRecording logs when Session Replay did not initialize', () async {
      when(
        () => mockPlatform.enable(any(), any()),
      ).thenAnswer((_) => Future.value(false));

      final config = DatadogSessionReplayConfiguration(
        replaySampleRate: 100.0,
        startRecordingImmediately: false,
      );
      await DatadogSessionReplay.init(config, mockInternalLogger);

      DatadogSessionReplay.instance!.startRecording();

      verify(
        () => mockInternalLogger.log(
          CoreLoggerLevel.warn,
          any(
            that: predicate<String>(
              (m) => m.contains('ignored'),
            ),
          ),
        ),
      );
    });

    test(
      'startRecording after deferred init starts capture without second enable',
      () async {
        when(
          () => mockPlatform.enable(any(), any()),
        ).thenAnswer((_) => Future.value(true));

        final config = DatadogSessionReplayConfiguration(
          replaySampleRate: 100.0,
          startRecordingImmediately: false,
        );
        await DatadogSessionReplay.init(config, mockInternalLogger);

        final sr = DatadogSessionReplay.instance!;
        expect(sr.debugIsRecordingForTest, isFalse);
        expect(sr.debugIsCaptureTimerActiveForTest, isFalse);

        sr.startRecording();
        expect(sr.debugIsRecordingForTest, isTrue);
        expect(sr.debugIsCaptureTimerActiveForTest, isTrue);

        sr.stopRecording();
        expect(sr.debugIsRecordingForTest, isFalse);
        expect(sr.debugIsCaptureTimerActiveForTest, isFalse);

        verify(() => mockPlatform.enable(config, any())).called(1);
      },
    );

    test('stopRecording is idempotent when never started', () async {
      when(
        () => mockPlatform.enable(any(), any()),
      ).thenAnswer((_) => Future.value(true));

      final config = DatadogSessionReplayConfiguration(
        replaySampleRate: 100.0,
        startRecordingImmediately: false,
      );
      await DatadogSessionReplay.init(config, mockInternalLogger);

      final sr = DatadogSessionReplay.instance!;
      expect(sr.debugIsRecordingForTest, isFalse);
      expect(sr.debugIsCaptureTimerActiveForTest, isFalse);

      sr.stopRecording();
      sr.stopRecording();
      sr.stopRecording();

      expect(sr.debugIsRecordingForTest, isFalse);
      expect(sr.debugIsCaptureTimerActiveForTest, isFalse);
      verify(() => mockPlatform.enable(config, any())).called(1);
    });

    test('startRecording is idempotent when called twice', () async {
      when(
        () => mockPlatform.enable(any(), any()),
      ).thenAnswer((_) => Future.value(true));

      final config = DatadogSessionReplayConfiguration(
        replaySampleRate: 100.0,
        startRecordingImmediately: false,
      );
      await DatadogSessionReplay.init(config, mockInternalLogger);

      final sr = DatadogSessionReplay.instance!;
      sr.startRecording();
      expect(sr.debugIsCaptureTimerActiveForTest, isTrue);
      sr.startRecording();
      expect(sr.debugIsCaptureTimerActiveForTest, isTrue);

      verify(() => mockPlatform.enable(config, any())).called(1);
    });

    test('startRecording is idempotent when already auto-started', () async {
      when(
        () => mockPlatform.enable(any(), any()),
      ).thenAnswer((_) => Future.value(true));

      final config = DatadogSessionReplayConfiguration(
        replaySampleRate: 100.0,
        startRecordingImmediately: true,
      );
      await DatadogSessionReplay.init(config, mockInternalLogger);

      final sr = DatadogSessionReplay.instance!;
      expect(sr.debugIsCaptureTimerActiveForTest, isTrue);
      sr.startRecording();
      expect(sr.debugIsCaptureTimerActiveForTest, isTrue);

      verify(() => mockPlatform.enable(config, any())).called(1);
    });

    test('stopRecording is idempotent after stop', () async {
      when(
        () => mockPlatform.enable(any(), any()),
      ).thenAnswer((_) => Future.value(true));

      final config = DatadogSessionReplayConfiguration(
        replaySampleRate: 100.0,
        startRecordingImmediately: false,
      );
      await DatadogSessionReplay.init(config, mockInternalLogger);

      final sr = DatadogSessionReplay.instance!;
      sr.startRecording();
      expect(sr.debugIsCaptureTimerActiveForTest, isTrue);
      sr.stopRecording();
      expect(sr.debugIsCaptureTimerActiveForTest, isFalse);
      sr.stopRecording();
      sr.stopRecording();
      expect(sr.debugIsCaptureTimerActiveForTest, isFalse);

      verify(() => mockPlatform.enable(config, any())).called(1);
    });

    test('repeated start and stop cycles do not call enable again', () async {
      when(
        () => mockPlatform.enable(any(), any()),
      ).thenAnswer((_) => Future.value(true));

      final config = DatadogSessionReplayConfiguration(
        replaySampleRate: 100.0,
        startRecordingImmediately: false,
      );
      await DatadogSessionReplay.init(config, mockInternalLogger);

      final sr = DatadogSessionReplay.instance!;
      sr.startRecording();
      expect(sr.debugIsCaptureTimerActiveForTest, isTrue);
      sr.stopRecording();
      expect(sr.debugIsCaptureTimerActiveForTest, isFalse);
      sr.startRecording();
      expect(sr.debugIsCaptureTimerActiveForTest, isTrue);
      sr.stopRecording();
      expect(sr.debugIsCaptureTimerActiveForTest, isFalse);
      sr.startRecording();
      expect(sr.debugIsCaptureTimerActiveForTest, isTrue);
      sr.stopRecording();
      expect(sr.debugIsCaptureTimerActiveForTest, isFalse);

      verify(() => mockPlatform.enable(config, any())).called(1);
    });

    // TODO: Test setup of Recorder / Processor?
  });
}
