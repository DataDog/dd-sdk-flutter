// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_noop.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockInternalLogger extends Mock implements InternalLogger {}

class MockDatadogSessionReplayPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DatadogSessionReplayPlatform {}

void main() {
  final DatadogSessionReplayPlatform initialPlatform =
      DatadogSessionReplayPlatform.instance;

  test('$DatadogSessionReplayPlatformNoop is the default instance', () {
    expect(initialPlatform, isInstanceOf<DatadogSessionReplayPlatformNoop>());
  });

  group('DatadogSessionReplay', () {
    final mockPlatform = MockDatadogSessionReplayPlatform();
    final mockInternalLogger = MockInternalLogger();

    setUp(() {
      WidgetsFlutterBinding.ensureInitialized();
      // Replace the default platform with the mock one
      DatadogSessionReplayPlatform.instance = mockPlatform;

      registerFallbackValue(
        DatadogSessionReplayConfiguration(replaySampleRate: 100),
      );

      when(() => mockPlatform.enable(any(), any()))
          .thenAnswer((_) => Future.value(false));
      when(() => mockPlatform.startRecording()).thenAnswer((_) async {});
      when(() => mockPlatform.stopRecording()).thenAnswer((_) async {});
      when(() => mockPlatform.setHasReplay(any(), any()))
          .thenAnswer((_) async {});
    });

    tearDown(() {
      // Cancel any timer started by startRecording().
      DatadogSessionReplay.stopRecording();
    });

    test('.init() calls enable on platform', () {
      // Given — enable returns false (already stubbed in setUp)

      // When
      final config = DatadogSessionReplayConfiguration(replaySampleRate: 100.0);
      DatadogSessionReplay.init(config, mockInternalLogger);

      // Then
      verify(() => mockPlatform.enable(config, any()));
    });

    group('start/stop recording', () {
      test(
          'startRecordingImmediately: false does not call platform.startRecording()',
          () async {
        await DatadogSessionReplay.init(
          DatadogSessionReplayConfiguration(
            replaySampleRate: 100.0,
            startRecordingImmediately: false,
          ),
          mockInternalLogger,
        );

        verifyNever(() => mockPlatform.startRecording());
      });

      test(
          'DatadogSessionReplay.startRecording() calls platform.startRecording()',
          () async {
        await DatadogSessionReplay.init(
          DatadogSessionReplayConfiguration(
            replaySampleRate: 100.0,
            startRecordingImmediately: false,
          ),
          mockInternalLogger,
        );

        DatadogSessionReplay.startRecording();

        verify(() => mockPlatform.startRecording()).called(1);
      });

      test('DatadogSessionReplay.stopRecording() calls platform.stopRecording()',
          () async {
        await DatadogSessionReplay.init(
          DatadogSessionReplayConfiguration(
            replaySampleRate: 100.0,
            startRecordingImmediately: false,
          ),
          mockInternalLogger,
        );
        DatadogSessionReplay.startRecording();

        DatadogSessionReplay.stopRecording();

        verify(() => mockPlatform.stopRecording()).called(1);
      });

      test('calling startRecording() twice is a no-op on the second call',
          () async {
        await DatadogSessionReplay.init(
          DatadogSessionReplayConfiguration(
            replaySampleRate: 100.0,
            startRecordingImmediately: false,
          ),
          mockInternalLogger,
        );

        DatadogSessionReplay.startRecording();
        DatadogSessionReplay.startRecording();

        verify(() => mockPlatform.startRecording()).called(1);
      });

      test('calling stopRecording() when not recording is a no-op', () async {
        await DatadogSessionReplay.init(
          DatadogSessionReplayConfiguration(
            replaySampleRate: 100.0,
            startRecordingImmediately: false,
          ),
          mockInternalLogger,
        );

        DatadogSessionReplay.stopRecording();

        verifyNever(() => mockPlatform.stopRecording());
      });

      test('startRecording() after stopRecording() resumes recording',
          () async {
        await DatadogSessionReplay.init(
          DatadogSessionReplayConfiguration(
            replaySampleRate: 100.0,
            startRecordingImmediately: false,
          ),
          mockInternalLogger,
        );

        DatadogSessionReplay.startRecording();
        DatadogSessionReplay.stopRecording();
        DatadogSessionReplay.startRecording();

        verify(() => mockPlatform.startRecording()).called(2);
        verify(() => mockPlatform.stopRecording()).called(1);
      });
    });

    // TODO: Test setup of Recorder / Processor?
  });
}
