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
  final DatadogSessionReplayPlatform initialPlatform =
      DatadogSessionReplayPlatform.instance;

  test('$DatadogSessionReplayPlatformNoop is the default instance', () {
    expect(initialPlatform, isInstanceOf<DatadogSessionReplayPlatformNoop>());
  });

  test('DatadogSessionReplayConfiguration default iconRasterLogicalSize is 20',
      () {
    final c = DatadogSessionReplayConfiguration(replaySampleRate: 100.0);
    expect(c.iconRasterLogicalSize, 20.0);
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
  });
}
