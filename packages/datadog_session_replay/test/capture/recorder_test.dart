// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/pointer_capture.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/capture/view_tree_snapshot.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:datadog_session_replay/src/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'simple_test_capture.dart';

class MockElement extends Mock implements Element {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return super.toString();
  }
}

class MockElementRecorder extends Mock implements ElementRecorder {
  @override
  bool accepts(Widget widget) =>
      widget is SimpleTestCapture || widget is Placeholder || widget is Center;
}

class MockCaptureNode extends Mock implements CaptureNode {}

class MockPointerSnapshotRecorder extends Mock
    implements PointerSnapshotRecorder {}

class MockTimeProvider extends Mock implements DatadogTimeProvider {}

void main() {
  late SessionReplayRecorder recorder;
  late MockTimeProvider mockTimeProvider;
  DateTime expectedDateTime = DateTime(2025, 3, 5, 10, 22, 11);

  group('null capture states', () {
    setUp(() {
      mockTimeProvider = MockTimeProvider();
      when(() => mockTimeProvider.now()).thenReturn(expectedDateTime);
      recorder = SessionReplayRecorder(
        timeProvider: mockTimeProvider,
        defaultCapturePrivacy: TreeCapturePrivacy(
          textAndInputPrivacyLevel:
              TextAndInputPrivacyLevel.maskSensitiveInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
        ),
        touchPrivacyLevel: TouchPrivacyLevel.show,
      );
    });

    test('capture with no context returns null ', () async {
      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNull);
    });

    test('capture with context and no elements returns null', () async {
      // Given
      recorder.updateContext(
        RUMContext(applicationId: randomString(), sessionId: randomString()),
      );

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNull);
    });
  });

  group('recorder', () {
    final mockRecorderA = MockElementRecorder();

    setUp(() {
      mockTimeProvider = MockTimeProvider();
      when(() => mockTimeProvider.now()).thenReturn(expectedDateTime);
      recorder = SessionReplayRecorder.withCustomRecorders(
        [mockRecorderA],
        timeProvider: mockTimeProvider,
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
      registerFallbackValue(
        TreeCapturePrivacy(
          textAndInputPrivacyLevel:
              TextAndInputPrivacyLevel.maskSensitiveInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
        ),
      );
      registerFallbackValue(MockElement());
    });

    testWidgets('capture specific recorded element returns view tree result', (
      tester,
    ) async {
      // Given
      when(
        () => mockRecorderA.captureSemantics(any(), captureAny(), any()),
      ).thenAnswer(
        (invocation) => SpecificElement(
          subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
          nodes: [MockCaptureNode()],
        ),
      );
      final context = RUMContext(
        applicationId: randomString(),
        sessionId: randomString(),
      );
      recorder.updateContext(context);

      // When
      final testedTree = SimpleTestCapture(
        key: UniqueKey(),
        recorder: recorder,
      );
      await tester.pumpWidget(testedTree);
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(capture!.viewTreeSnapshot.context, context);
      expect(capture.viewTreeSnapshot.nodes.length, 1);
    });

    testWidgets('snapshot time uses time from provider in view tree snapshot', (
      tester,
    ) async {
      // Given
      when(
        () => mockRecorderA.captureSemantics(any(), captureAny(), any()),
      ).thenAnswer(
        (invocation) => SpecificElement(
          subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
          nodes: [MockCaptureNode()],
        ),
      );
      final context = RUMContext(
        applicationId: randomString(),
        sessionId: randomString(),
      );
      recorder.updateContext(context);

      // When
      final testedTree = SimpleTestCapture(
        key: UniqueKey(),
        recorder: recorder,
      );
      await tester.pumpWidget(testedTree);
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(capture!.viewTreeSnapshot.date, expectedDateTime);
    });

    testWidgets(
      'capture ignores subtree when CaptureNodeSubtreeStrategy.ignore',
      (tester) async {
        // Given
        when(
          () => mockRecorderA.captureSemantics(any(), captureAny(), any()),
        ).thenAnswer(
          (invocation) => SpecificElement(
            subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
            nodes: [MockCaptureNode()],
          ),
        );
        final context = RUMContext(
          applicationId: randomString(),
          sessionId: randomString(),
        );
        recorder.updateContext(context);

        // When
        final testedTree = SimpleTestCapture(
          key: UniqueKey(),
          recorder: recorder,
        );
        await tester.pumpWidget(testedTree);
        final capture = await recorder.performCapture();

        // Then
        expect(capture, isNotNull);
        expect(capture!.viewTreeSnapshot.context, context);
        expect(capture.viewTreeSnapshot.nodes.length, 1);
      },
    );

    testWidgets('capture subtree when CaptureNodeSubtreeStrategy.record', (
      tester,
    ) async {
      // Given
      when(
        () => mockRecorderA.captureSemantics(any(), captureAny(), any()),
      ).thenAnswer((invocation) {
        var subtreeStrategy = CaptureNodeSubtreeStrategy.record;
        if ((invocation.positionalArguments[0] as Element).widget
            is Placeholder) {
          subtreeStrategy = CaptureNodeSubtreeStrategy.ignore;
        }
        return SpecificElement(
          subtreeStrategy: subtreeStrategy,
          nodes: [MockCaptureNode()],
        );
      });
      final context = RUMContext(
        applicationId: randomString(),
        sessionId: randomString(),
      );
      recorder.updateContext(context);

      // When
      final testedTree = SimpleTestCapture(
        key: UniqueKey(),
        recorder: recorder,
        child: Center(child: Placeholder()),
      );
      await tester.pumpWidget(testedTree);
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(capture!.viewTreeSnapshot.nodes.length, 3);
    });

    testWidgets('capture subtree passes new capture privacy when overwritten', (
      tester,
    ) async {
      // Given
      when(
        () => mockRecorderA.captureSemantics(any(), captureAny(), any()),
      ).thenAnswer((invocation) {
        var subtreeStrategy = CaptureNodeSubtreeStrategy.record;
        if ((invocation.positionalArguments[0] as Element).widget
            is Placeholder) {
          subtreeStrategy = CaptureNodeSubtreeStrategy.ignore;
        }
        return SpecificElement(
          subtreeStrategy: subtreeStrategy,
          subtreePrivacy: TreeCapturePrivacy(
            textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
            imagePrivacyLevel: ImagePrivacyLevel.maskAll,
          ),
          nodes: [MockCaptureNode()],
        );
      });
      final context = RUMContext(
        applicationId: randomString(),
        sessionId: randomString(),
      );
      recorder.updateContext(context);

      // When
      final testedTree = SimpleTestCapture(
        key: UniqueKey(),
        recorder: recorder,
        child: Center(child: Placeholder()),
      );
      await tester.pumpWidget(testedTree);
      final _ = recorder.performCapture();

      // Then
      verifyInOrder([
        () => mockRecorderA.captureSemantics(
              any(),
              any(),
              TreeCapturePrivacy(
                textAndInputPrivacyLevel:
                    TextAndInputPrivacyLevel.maskSensitiveInputs,
                imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
              ),
            ),
        () => mockRecorderA.captureSemantics(
              any(),
              any(),
              TreeCapturePrivacy(
                textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
                imagePrivacyLevel: ImagePrivacyLevel.maskAll,
              ),
            ),
      ]);
    });

    testWidgets('recorder ignores trees with Visibility(false)', (
      tester,
    ) async {
      // Given
      when(
        () => mockRecorderA.captureSemantics(any(), captureAny(), any()),
      ).thenAnswer(
        (invocation) => SpecificElement(
          subtreeStrategy: CaptureNodeSubtreeStrategy.record,
          nodes: [MockCaptureNode()],
        ),
      );
      final context = RUMContext(
        applicationId: randomString(),
        sessionId: randomString(),
      );
      recorder.updateContext(context);

      // When
      final testedTree = SimpleTestCapture(
        key: UniqueKey(),
        recorder: recorder,
        child: Visibility(visible: false, child: Center(child: Placeholder())),
      );
      await tester.pumpWidget(testedTree);
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(capture!.viewTreeSnapshot.context, context);
      expect(capture.viewTreeSnapshot.nodes.length, 1);
    });

    testWidgets('recorder captures trees with Visibility(true)', (
      tester,
    ) async {
      // Given
      when(
        () => mockRecorderA.captureSemantics(any(), captureAny(), any()),
      ).thenAnswer(
        (invocation) => SpecificElement(
          subtreeStrategy: CaptureNodeSubtreeStrategy.record,
          nodes: [MockCaptureNode()],
        ),
      );
      final context = RUMContext(
        applicationId: randomString(),
        sessionId: randomString(),
      );
      recorder.updateContext(context);

      // When
      final testedTree = SimpleTestCapture(
        key: UniqueKey(),
        recorder: recorder,
        child: Visibility(visible: true, child: Center(child: Placeholder())),
      );
      await tester.pumpWidget(testedTree);
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(capture!.viewTreeSnapshot.context, context);
      expect(capture.viewTreeSnapshot.nodes.length, greaterThan(1));
    });

    testWidgets('capture uses recorder nodes with highest importance', (
      tester,
    ) async {
      // Given
      final lowImportanceRecorder = MockElementRecorder();
      when(
        () =>
            lowImportanceRecorder.captureSemantics(any(), captureAny(), any()),
      ).thenAnswer((invocation) {
        return AmbiguousElement(
          subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
          nodes: [MockCaptureNode(), MockCaptureNode()],
        );
      });
      when(
        () => mockRecorderA.captureSemantics(any(), captureAny(), any()),
      ).thenAnswer((invocation) {
        return SpecificElement(
          subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
          nodes: [MockCaptureNode()],
        );
      });
      final context = RUMContext(
        applicationId: randomString(),
        sessionId: randomString(),
      );
      recorder.updateContext(context);

      // When
      final testedTree = SimpleTestCapture(
        key: UniqueKey(),
        recorder: recorder,
      );
      await tester.pumpWidget(testedTree);
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      // The 2 nodes that come from the low importance recorder
      // (AmbiguousElement) are discarded in favor of the 1 node from the high
      // importance one (SpecificElement)
      expect(capture!.viewTreeSnapshot.nodes.length, 1);
    });
  });

  group('pointer capture', () {
    setUp(() {
      registerFallbackValue(
        CapturedViewAttributes(
          paintBounds: Rect.zero,
          scaleX: 1.0,
          scaleY: 1.0,
        ),
      );
      registerFallbackValue(MockElement());

      final mockElementRecorder = MockElementRecorder();
      when(
        () => mockElementRecorder.captureSemantics(any(), captureAny(), any()),
      ).thenAnswer(
        (invocation) => SpecificElement(
          subtreeStrategy: CaptureNodeSubtreeStrategy.record,
          nodes: [MockCaptureNode()],
        ),
      );
      recorder = SessionReplayRecorder.withCustomRecorders(
        [mockElementRecorder],
        defaultCapturePrivacy: TreeCapturePrivacy(
          textAndInputPrivacyLevel:
              TextAndInputPrivacyLevel.maskSensitiveInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNone,
        ),
        touchPrivacyLevel: TouchPrivacyLevel.show,
      );
    });

    testWidgets('pointer recorder snapshot returned from capture', (
      tester,
    ) async {
      // Given
      final mockPointerRecorder = MockPointerSnapshotRecorder();
      final expectedPointerNodes = <PointerCapture>[
        PointerCapture(
          date: DateTime.now(),
          pointerId: 0,
          eventType: SRPointerEventType.down,
          x: randomDouble(),
          y: randomDouble(),
        ),
        PointerCapture(
          date: DateTime.now().add(Duration(milliseconds: 100)),
          pointerId: 0,
          eventType: SRPointerEventType.up,
          x: randomDouble(),
          y: randomDouble(),
        ),
      ];
      when(
        () => mockPointerRecorder.takeSnapshot(),
      ).thenReturn(PointerSnapshot(DateTime.now(), expectedPointerNodes));
      final context = RUMContext(
        applicationId: randomString(),
        sessionId: randomString(),
      );
      recorder.updateContext(context);

      // When
      final testedTree = SimpleTestCapture(
        key: UniqueKey(),
        recorder: recorder,
        child: PointerRecorder(
          pointerRecorder: mockPointerRecorder,
          child: Placeholder(),
        ),
      );
      await tester.pumpWidget(testedTree);
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(capture!.pointerSnapshot, isNotNull);
      expect(capture.pointerSnapshot!.pointerEvents, expectedPointerNodes);
    });
  });
}
