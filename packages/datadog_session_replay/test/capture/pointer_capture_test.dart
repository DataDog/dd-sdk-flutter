// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/container_recorder.dart';
import 'package:datadog_session_replay/src/capture/pointer_capture.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:datadog_session_replay/src/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'simple_test_capture.dart';

class MockTimeProvider extends Mock implements DatadogTimeProvider {}

void main() {
  group('PointerSnapshotRecorder', () {
    late MockTimeProvider mockTimeProvider;

    setUp(() {
      mockTimeProvider = MockTimeProvider();
    });

    group('capturePointer', () {
      test('rejects pointer events when isCapturing returns false', () {
        // Given
        final mockTime = DateTime(2024, 1, 2, 3, 0, 0);
        when(() => mockTimeProvider.now()).thenReturn(mockTime);
        final recorder = PointerSnapshotRecorder(
          mockTimeProvider,
          isCapturing: () => false,
        );

        // When
        recorder.capturePointer(
          1,
          SRPointerEventType.down,
          randomDouble(),
          randomDouble(),
        );

        // Then
        expect(recorder.takeSnapshot(), isNull);
      });

      test('captures pointer events when isCapturing returns true', () {
        // Given
        var capturing = true;
        final mockTime = DateTime(2024, 1, 2, 3, 0, 0);
        when(() => mockTimeProvider.now()).thenReturn(mockTime);
        final recorder = PointerSnapshotRecorder(
          mockTimeProvider,
          isCapturing: () => capturing,
        );

        // When
        recorder.capturePointer(1, SRPointerEventType.down, 1.0, 2.0);
        capturing = false;
        recorder.capturePointer(1, SRPointerEventType.move, 3.0, 4.0);

        // Then
        final snapshot = recorder.takeSnapshot();
        expect(snapshot, isNotNull);
        expect(snapshot!.pointerEvents, hasLength(1));
        expect(snapshot.pointerEvents[0].eventType, SRPointerEventType.down);
      });

      test('adds pointer event to snapshot', () {
        // Given
        final mockTime = DateTime(2024, 1, 2, 3, 0, 0);
        when(() => mockTimeProvider.now()).thenReturn(mockTime);
        final recorder = PointerSnapshotRecorder(mockTimeProvider);

        // When
        final x = randomDouble();
        final y = randomDouble();
        recorder.capturePointer(1, SRPointerEventType.down, x, y);

        // Then
        final snapshot = recorder.takeSnapshot();
        expect(snapshot, isNotNull);
        expect(snapshot!.pointerEvents, hasLength(1));
        expect(snapshot.pointerEvents[0].pointerId, 1);
        expect(snapshot.pointerEvents[0].eventType, SRPointerEventType.down);
        expect(snapshot.pointerEvents[0].x, x);
        expect(snapshot.pointerEvents[0].y, y);
        expect(snapshot.pointerEvents[0].date, mockTime);
      });

      test('captures multiple events in order', () {
        // Given
        final time1 = DateTime(2023, 1, 1, 12, 0, 0);
        final time2 = DateTime(2023, 1, 1, 12, 0, 1);
        final time3 = DateTime(2023, 1, 1, 12, 0, 2);
        final recorder = PointerSnapshotRecorder(mockTimeProvider);

        when(() => mockTimeProvider.now()).thenReturn(time1);
        final x = randomDouble();
        final y = randomDouble();
        recorder.capturePointer(1, SRPointerEventType.down, x, y);

        when(() => mockTimeProvider.now()).thenReturn(time2);
        recorder.capturePointer(1, SRPointerEventType.move, x + 10.0, y + 10.0);

        when(() => mockTimeProvider.now()).thenReturn(time3);
        recorder.capturePointer(1, SRPointerEventType.up, x + 10.0, y + 10.0);

        // When
        final snapshot = recorder.takeSnapshot();
        expect(snapshot, isNotNull);
        expect(snapshot!.pointerEvents, hasLength(3));
        expect(snapshot.firstRecord, time1);

        // Then
        expect(snapshot.pointerEvents[0].eventType, SRPointerEventType.down);
        expect(snapshot.pointerEvents[0].date, time1);
        expect(snapshot.pointerEvents[0].x, x);
        expect(snapshot.pointerEvents[0].y, y);

        expect(snapshot.pointerEvents[1].eventType, SRPointerEventType.move);
        expect(snapshot.pointerEvents[1].date, time2);
        expect(snapshot.pointerEvents[1].x, x + 10.0);
        expect(snapshot.pointerEvents[1].y, y + 10.0);

        expect(snapshot.pointerEvents[2].eventType, SRPointerEventType.up);
        expect(snapshot.pointerEvents[2].date, time3);
        expect(snapshot.pointerEvents[2].x, x + 10.0);
        expect(snapshot.pointerEvents[2].y, y + 10.0);
      });

      test('captures events from multiple pointers', () {
        // Given
        final mockTime = DateTime(2024, 1, 2, 3, 0, 0);
        when(() => mockTimeProvider.now()).thenReturn(mockTime);
        final recorder = PointerSnapshotRecorder(mockTimeProvider);

        // When
        final x1 = randomDouble();
        final y1 = randomDouble();
        final x2 = randomDouble();
        final y2 = randomDouble();
        recorder.capturePointer(1, SRPointerEventType.down, x1, y1);
        recorder.capturePointer(2, SRPointerEventType.down, x2, y2);

        // Then
        final snapshot = recorder.takeSnapshot();
        expect(snapshot, isNotNull);
        expect(snapshot!.pointerEvents, hasLength(2));

        expect(snapshot.pointerEvents[0].pointerId, 1);
        expect(snapshot.pointerEvents[0].x, x1);
        expect(snapshot.pointerEvents[0].y, y1);
        expect(snapshot.pointerEvents[0].eventType, SRPointerEventType.down);
        expect(snapshot.pointerEvents[1].pointerId, 2);
        expect(snapshot.pointerEvents[1].x, x2);
        expect(snapshot.pointerEvents[1].y, y2);
        expect(snapshot.pointerEvents[1].eventType, SRPointerEventType.down);
      });

      test('handles all pointer event types correctly', () {
        // Given
        final mockTime = DateTime(2024, 1, 2, 3, 0, 0);
        when(() => mockTimeProvider.now()).thenReturn(mockTime);
        final recorder = PointerSnapshotRecorder(mockTimeProvider);

        // When
        recorder.capturePointer(
          1,
          SRPointerEventType.down,
          randomDouble(),
          randomDouble(),
        );
        recorder.capturePointer(
          2,
          SRPointerEventType.move,
          randomDouble(),
          randomDouble(),
        );
        recorder.capturePointer(
          3,
          SRPointerEventType.up,
          randomDouble(),
          randomDouble(),
        );
        final snapshot = recorder.takeSnapshot();

        // Then
        expect(snapshot, isNotNull);
        expect(snapshot!.pointerEvents, hasLength(3));

        expect(snapshot.pointerEvents[0].eventType, SRPointerEventType.down);
        expect(snapshot.pointerEvents[1].eventType, SRPointerEventType.move);
        expect(snapshot.pointerEvents[2].eventType, SRPointerEventType.up);
      });
    });

    group('uncapturePointer', () {
      test('adds pointer to hidden set', () {
        // Given
        final mockTime = DateTime(2024, 1, 2, 3, 0, 0);
        when(() => mockTimeProvider.now()).thenReturn(mockTime);
        final recorder = PointerSnapshotRecorder(mockTimeProvider);

        // When
        final x = randomDouble();
        final y = randomDouble();
        recorder.capturePointer(1, SRPointerEventType.down, x, y);
        recorder.uncapturePointer(1);
        recorder.capturePointer(1, SRPointerEventType.move, x, y);

        // Assert - should have no events since pointer 1 is hidden
        final snapshot = recorder.takeSnapshot();
        expect(snapshot, isNull);
      });

      test('removes existing events from hidden pointer', () {
        // Given
        final mockTime = DateTime(2024, 1, 2, 3, 0, 0);
        when(() => mockTimeProvider.now()).thenReturn(mockTime);
        final recorder = PointerSnapshotRecorder(mockTimeProvider);

        // When
        recorder.capturePointer(1, SRPointerEventType.down, 100.0, 200.0);
        recorder.capturePointer(2, SRPointerEventType.down, 300.0, 400.0);
        recorder.capturePointer(1, SRPointerEventType.move, 110.0, 210.0);

        // Hide pointer 1
        recorder.uncapturePointer(1);

        // Then
        final snapshot = recorder.takeSnapshot();
        expect(snapshot, isNotNull);
        expect(snapshot!.pointerEvents, hasLength(1));
        expect(snapshot.pointerEvents[0].pointerId, 2);
      });

      test('can hide pointer that does not exist in buffer', () {
        // Given
        final mockTime = DateTime(2024, 1, 2, 3, 0, 0);
        when(() => mockTimeProvider.now()).thenReturn(mockTime);
        final recorder = PointerSnapshotRecorder(mockTimeProvider);

        // Hide a pointer that was never captured
        expect(() => recorder.uncapturePointer(999), returnsNormally);

        // Should still be able to capture other events
        recorder.capturePointer(1, SRPointerEventType.down, 100.0, 200.0);

        // Then
        final snapshot = recorder.takeSnapshot();
        expect(snapshot, isNotNull);
        expect(snapshot!.pointerEvents, hasLength(1));
      });

      test('can hide multiple pointers', () {
        // Given
        final mockTime = DateTime(2024, 1, 2, 3, 0, 0);
        when(() => mockTimeProvider.now()).thenReturn(mockTime);
        final recorder = PointerSnapshotRecorder(mockTimeProvider);

        // Capture events from multiple pointers
        recorder.capturePointer(1, SRPointerEventType.down, 100.0, 200.0);
        recorder.capturePointer(2, SRPointerEventType.down, 200.0, 300.0);
        recorder.capturePointer(3, SRPointerEventType.down, 300.0, 400.0);

        // Hide multiple pointers
        recorder.uncapturePointer(1);
        recorder.uncapturePointer(3);

        // Then - should only have events from pointer 2
        final snapshot = recorder.takeSnapshot();
        expect(snapshot, isNotNull);
        expect(snapshot!.pointerEvents, hasLength(1));
        expect(snapshot.pointerEvents[0].pointerId, 2);
      });
    });

    group('takeSnapshot', () {
      test('returns null when buffer is empty', () {
        // Given
        final mockTime = DateTime(2024, 1, 2, 3, 0, 0);
        when(() => mockTimeProvider.now()).thenReturn(mockTime);
        final recorder = PointerSnapshotRecorder(mockTimeProvider);

        // When
        final snapshot = recorder.takeSnapshot();

        // Then
        expect(snapshot, isNull);
      });

      test('returns snapshot with correct first record time', () {
        // Given
        final time1 = DateTime(2023, 1, 1, 12, 0, 0);
        final time2 = DateTime(2023, 1, 1, 12, 0, 5);
        final recorder = PointerSnapshotRecorder(mockTimeProvider);

        // When
        when(() => mockTimeProvider.now()).thenReturn(time1);
        recorder.capturePointer(1, SRPointerEventType.down, 100.0, 200.0);

        when(() => mockTimeProvider.now()).thenReturn(time2);
        recorder.capturePointer(1, SRPointerEventType.up, 110.0, 210.0);

        // Then
        final snapshot = recorder.takeSnapshot();
        expect(snapshot, isNotNull);
        expect(snapshot!.firstRecord, time1); // Should be time of first event
      });

      test('clears buffer after taking snapshot', () {
        // Given
        final mockTime = DateTime(2024, 1, 2, 3, 0, 0);
        when(() => mockTimeProvider.now()).thenReturn(mockTime);
        final recorder = PointerSnapshotRecorder(mockTimeProvider);

        // When
        recorder.capturePointer(1, SRPointerEventType.down, 100.0, 200.0);

        final snapshot1 = recorder.takeSnapshot();
        expect(snapshot1, isNotNull);
        expect(snapshot1!.pointerEvents, hasLength(1));

        // Then
        final snapshot2 = recorder.takeSnapshot();
        expect(snapshot2, isNull);
      });

      test('clears hidden pointers set after taking snapshot', () {
        // Given
        final mockTime = DateTime(2024, 1, 2, 3, 0, 0);
        when(() => mockTimeProvider.now()).thenReturn(mockTime);
        final recorder = PointerSnapshotRecorder(mockTimeProvider);

        // Hide a pointer
        recorder.uncapturePointer(1);

        // Capture an event from another pointer
        recorder.capturePointer(2, SRPointerEventType.down, 100.0, 200.0);

        // Take snapshot (this should clear hidden pointers)
        final snapshot1 = recorder.takeSnapshot();
        expect(snapshot1, isNotNull);

        // Now pointer 1 should no longer be hidden
        recorder.capturePointer(1, SRPointerEventType.down, 200.0, 300.0);

        final snapshot2 = recorder.takeSnapshot();
        expect(snapshot2, isNotNull);
        expect(snapshot2!.pointerEvents, hasLength(1));
        expect(snapshot2.pointerEvents[0].pointerId, 1);
      });

      test('returns copy of buffer, not reference', () {
        // Given
        final mockTime = DateTime(2024, 1, 2, 3, 0, 0);
        when(() => mockTimeProvider.now()).thenReturn(mockTime);
        final recorder = PointerSnapshotRecorder(mockTimeProvider);

        // When
        recorder.capturePointer(1, SRPointerEventType.down, 100.0, 200.0);
        final snapshot = recorder.takeSnapshot();

        // Modify the returned list
        snapshot!.pointerEvents.clear();

        // Then
        final snapshot2 = recorder.takeSnapshot();
        expect(snapshot2, isNull);
      });
    });
  });

  group('widget tests', () {
    late SessionReplayRecorder recorder;
    late RUMContext context;

    setUp(() {
      final keyGenerator = KeyGenerator();
      recorder = SessionReplayRecorder.withCustomRecorders(
        [ContainerRecorder(keyGenerator)],
        defaultCapturePrivacy: TreeCapturePrivacy(
          textAndInputPrivacyLevel:
              TextAndInputPrivacyLevel.maskSensitiveInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
        ),
        touchPrivacyLevel: TouchPrivacyLevel.show,
      );

      registerFallbackValue(
        CapturedViewAttributes(
          paintBounds: Rect.zero,
          scaleX: 1.0,
          scaleY: 1.0,
        ),
      );

      context = RUMContext(
        applicationId: randomString(),
        sessionId: randomString(),
      );
      recorder.updateContext(context);
    });

    testWidgets('records taps on widgets', (tester) async {
      // Given
      final x = randomDouble(min: 10, max: 50);
      final y = randomDouble(min: 10, max: 50);
      final pointerRecorder = PointerSnapshotRecorder(DefaultTimeProvider());

      bool didTapButton = false;
      final tree = MaterialApp(
        home: SimpleTestCapture(
          key: Key('key'),
          recorder: recorder,
          child: PointerRecorder(
            pointerRecorder: pointerRecorder,
            child: Stack(
              children: [
                Positioned(
                  top: y,
                  left: x,
                  width: 50.0,
                  height: 50.0,
                  child: MaterialButton(
                    onPressed: () {
                      didTapButton = true;
                    },
                    child: Text('Test Button'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree);
      await tester.tap(find.byType(MaterialButton));
      await tester.pumpAndSettle();

      // When
      CaptureResult? capture;
      await tester.runAsync(() async {
        capture = await recorder.performCapture();
      });

      // Then
      expect(didTapButton, isTrue);
      expect(capture!.pointerSnapshot, isNotNull);
      final pointerEvents = capture!.pointerSnapshot!.pointerEvents;
      expect(pointerEvents.length, 2);

      final firstPointer = capture!.pointerSnapshot!.pointerEvents[0];
      expect(firstPointer.eventType, SRPointerEventType.down);
      expect(firstPointer.x, greaterThan(x));
      expect(firstPointer.y, greaterThan(y));

      final secondPointer = capture!.pointerSnapshot!.pointerEvents[1];
      expect(secondPointer.eventType, SRPointerEventType.up);
      expect(secondPointer.x, greaterThan(x));
      expect(secondPointer.y, greaterThan(y));
    });
  });
}
