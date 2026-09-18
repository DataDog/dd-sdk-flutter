// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/pointer_capture.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/capture/view_tree_snapshot.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:datadog_session_replay/src/extensions.dart';
import 'package:datadog_session_replay/src/processor/font_family_transform.dart';
import 'package:datadog_session_replay/src/processor/processor_worker.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../test_utils.dart';

class MockDatadogSessionReplayPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DatadogSessionReplayPlatform {}

class MockCaptureNode extends Mock implements CaptureNode {}

SRShapeWireframe createMockShapeWireframe(int id) {
  return SRShapeWireframe(
    id: id,
    x: randomInt(),
    y: randomInt(),
    width: randomInt(),
    height: randomInt(),
    shapeStyle: SRShapeStyle(
      cornerRadius: randomDouble(min: 0.0, max: 5.0),
      backgroundColor: randomColor().toHexString(),
    ),
  );
}

void main() {
  late MockDatadogSessionReplayPlatform mockPlatform;

  void initializeMockPlatform() {
    mockPlatform = MockDatadogSessionReplayPlatform();
    DatadogSessionReplayPlatform.instance = mockPlatform;

    when(
      () => mockPlatform.setHasReplay(any(), any()),
    ).thenAnswer((_) => Future.value());
    when(
      () => mockPlatform.setRecordCount(any(), any()),
    ).thenAnswer((_) => Future.value());
    when(
      () => mockPlatform.writeSegment(any(), any()),
    ).thenAnswer((_) => Future.value());
  }

  setUp(() {
    initializeMockPlatform();
  });

  test('processSnapshot for no viewId does nothing', () async {
    // Given
    final ProcessorWorker worker = ProcessorWorker();
    final capture = CaptureResult(
      ViewTreeSnapshot(
        date: DateTime.now(),
        context: RUMContext(
          applicationId: randomString(),
          sessionId: randomString(),
        ),
        viewportSize: Size(600, 800),
        nodes: [MockCaptureNode()],
      ),
      null,
    );

    // When
    await worker.processSnapshot(capture);

    // Then
    verifyNoMoreInteractions(mockPlatform);
  });

  test('generateWireframes maps text wireframe font family via smart transform',
      () {
    final mockCapture = MockCaptureNode();
    final original = SRTextWireframe(
      id: 5,
      x: 0,
      y: 0,
      width: 100,
      height: 20,
      text: 'hello',
      textStyle: SRTextStyle(
        color: '#FF000000',
        family: '',
        size: 14,
      ),
    );
    when(() => mockCapture.buildWireframes()).thenReturn([original]);

    final worker = ProcessorWorker(
      fontFamilyTransform: const FontFamilyTransformConfig(
        strategy: FontFamilyStrategy.smart,
      ),
    );
    final capture = CaptureResult(
      ViewTreeSnapshot(
        date: DateTime.now(),
        context: RUMContext(
          applicationId: randomString(),
          sessionId: randomString(),
          viewId: randomString(),
        ),
        viewportSize: Size(600, 800),
        nodes: [mockCapture],
      ),
      null,
    );

    final wireframes = worker.generateWireframes(capture);
    expect(wireframes.length, 1);
    final text = wireframes.single as SRTextWireframe;
    expect(text.textStyle.family, defaultReplayFontStack);
    expect(identical(text, original), isFalse);
  });

  test('generateWireframes leaves non-text wireframes unchanged', () {
    final mockCapture = MockCaptureNode();
    final shape = createMockShapeWireframe(0);
    when(() => mockCapture.buildWireframes()).thenReturn([shape]);

    final worker =
        ProcessorWorker(fontFamilyTransform: const FontFamilyTransformConfig());
    final capture = CaptureResult(
      ViewTreeSnapshot(
        date: DateTime.now(),
        context: RUMContext(
          applicationId: randomString(),
          sessionId: randomString(),
          viewId: randomString(),
        ),
        viewportSize: Size(600, 800),
        nodes: [mockCapture],
      ),
      null,
    );

    final wireframes = worker.generateWireframes(capture);
    expect(wireframes.single, shape);
  });

  test('processSnapshot for first snapshot generates full record', () async {
    // Given
    final ProcessorWorker worker = ProcessorWorker();
    final mockCapture = MockCaptureNode();

    final mockShape = createMockShapeWireframe(0);
    when(() => mockCapture.buildWireframes()).thenReturn([mockShape]);
    final rumContext = RUMContext(
      applicationId: randomString(),
      sessionId: randomString(),
      viewId: randomString(),
    );
    final expectedTimestamp = DateTime.now();
    final capture = CaptureResult(
      ViewTreeSnapshot(
        date: expectedTimestamp,
        context: rumContext,
        viewportSize: Size(600, 800),
        nodes: [mockCapture],
      ),
      null,
    );

    // When
    await worker.processSnapshot(capture);

    // Then - Send a Meta, Focus, and Full Snapshot
    verify(() => mockPlatform.setRecordCount(rumContext.viewId!, 3));

    final expectedRecord = SREnrichedRecord(
      records: [
        SRMetaRecord(
          data: SRMetaRecordData(width: 600, height: 800),
          timestamp: expectedTimestamp.toUtc().millisecondsSinceEpoch,
        ),
        SRFocusRecord(
          data: SRFocusRecordData(hasFocus: true),
          timestamp: expectedTimestamp.toUtc().millisecondsSinceEpoch,
        ),
        SRFullSnapshotRecord(
          data: SRFullSnapshotRecordData(wireframes: [mockShape]),
          timestamp: expectedTimestamp.toUtc().millisecondsSinceEpoch,
        ),
      ],
      applicationID: rumContext.applicationId,
      sessionID: rumContext.sessionId,
      viewID: rumContext.viewId!,
    );
    final encodedRecord = jsonEncode(expectedRecord);
    verify(() => mockPlatform.writeSegment(encodedRecord, rumContext.viewId!));
  });

  group('with initial snapshot', () {
    initializeMockPlatform();

    final mockCapture = MockCaptureNode();

    final mockShape = createMockShapeWireframe(0);
    when(() => mockCapture.buildWireframes()).thenReturn([mockShape]);
    final rumContext = RUMContext(
      applicationId: randomString(),
      sessionId: randomString(),
      viewId: randomString(),
    );
    final firstTimestamp = DateTime.now();

    late ProcessorWorker worker;

    setUp(() async {
      worker = ProcessorWorker();
      final firstCapture = CaptureResult(
        ViewTreeSnapshot(
          date: firstTimestamp,
          context: rumContext,
          viewportSize: Size(600, 800),
          nodes: [mockCapture],
        ),
        null,
      );

      await worker.processSnapshot(firstCapture);

      // Sends a Meta, Focus, and FullSnapshot record
      verify(() => mockPlatform.setRecordCount(rumContext.viewId!, 3));
      verify(() => mockPlatform.writeSegment(any(), any()));
    });

    test('processSnapshot with no changes generates no records', () async {
      // Given
      final secondTimestamp = firstTimestamp.add(Duration(milliseconds: 200));
      final secondCapture = CaptureResult(
        ViewTreeSnapshot(
          date: secondTimestamp,
          context: rumContext,
          viewportSize: Size(600, 800),
          nodes: [mockCapture],
        ),
        null,
      );

      // When
      await worker.processSnapshot(secondCapture);

      // Then
      verifyNoMoreInteractions(mockPlatform);
    });

    test('processSnapshot with changes generates incremental record', () async {
      // Given
      final secondMockCapture = MockCaptureNode();
      final mockShape = createMockShapeWireframe(0);
      when(() => secondMockCapture.buildWireframes()).thenReturn([mockShape]);
      final secondTimestamp = firstTimestamp.add(Duration(milliseconds: 200));
      final secondCapture = CaptureResult(
        ViewTreeSnapshot(
          date: secondTimestamp,
          context: rumContext,
          viewportSize: Size(600, 800),
          nodes: [secondMockCapture],
        ),
        null,
      );

      // When
      await worker.processSnapshot(secondCapture);

      // Then
      final expectedRecord = SREnrichedRecord(
        records: [
          SRIncrementalSnapshotRecord(
            data: SRIncrementalMutationData(
              adds: [],
              removes: [],
              updates: [
                SRShapeWireframeUpdate(
                  id: 0,
                  border: null,
                  clip: null,
                  shapeStyle: mockShape.shapeStyle,
                  x: mockShape.x,
                  y: mockShape.y,
                  width: mockShape.width,
                  height: mockShape.height,
                ),
              ],
            ),
            timestamp: secondTimestamp.toUtc().millisecondsSinceEpoch,
          ),
        ],
        applicationID: rumContext.applicationId,
        sessionID: rumContext.sessionId,
        viewID: rumContext.viewId!,
      );
      final expectedJson = jsonEncode(expectedRecord);
      verify(() => mockPlatform.setRecordCount(rumContext.viewId!, 4));
      verify(() => mockPlatform.writeSegment(expectedJson, rumContext.viewId!));
    });

    test(
      'incremental record does not contain elements that did not change',
      () async {
        // Given
        final secondTimestamp = firstTimestamp.add(Duration(milliseconds: 200));
        final expectedRecord = SREnrichedRecord(
          records: [
            SRIncrementalSnapshotRecord(
              data: SRIncrementalMutationData(
                adds: [],
                removes: [],
                updates: [
                  SRShapeWireframeUpdate(
                    id: 0,
                    border: null,
                    clip: null,
                    shapeStyle: null,
                    x: null,
                    y: null,
                    width: mockShape.width,
                    height: mockShape.height,
                  ),
                ],
              ),
              timestamp: secondTimestamp.toUtc().millisecondsSinceEpoch,
            ),
          ],
          applicationID: rumContext.applicationId,
          sessionID: rumContext.sessionId,
          viewID: rumContext.viewId!,
        );

        // When
        final jsonRecord = jsonEncode(expectedRecord);
        final encodedRecord = jsonDecode(jsonRecord);

        // Then
        final encodedMutation = encodedRecord['records'][0]['data']['updates']
            [0] as Map<String, Object?>;
        expect(encodedMutation.containsKey('x'), isFalse);
        expect(encodedMutation.containsKey('y'), isFalse);
      },
    );

    test(
      'processSnapshot with changes generates incremental record (add / remove)',
      () async {
        // Given
        final secondMockCapture = MockCaptureNode();
        final mockShape = createMockShapeWireframe(1);
        when(() => secondMockCapture.buildWireframes()).thenReturn([mockShape]);
        final secondTimestamp = firstTimestamp.add(Duration(milliseconds: 200));
        final secondCapture = CaptureResult(
          ViewTreeSnapshot(
            date: secondTimestamp,
            context: rumContext,
            viewportSize: Size(600, 800),
            nodes: [secondMockCapture],
          ),
          null,
        );

        // When
        await worker.processSnapshot(secondCapture);

        // Then
        final expectedRecord = SREnrichedRecord(
          records: [
            SRIncrementalSnapshotRecord(
              data: SRIncrementalMutationData(
                adds: [SRIntrementalAdd(wireframe: mockShape)],
                removes: [SRIncrementalRemove(id: 0)],
                updates: [],
              ),
              timestamp: secondTimestamp.toUtc().millisecondsSinceEpoch,
            ),
          ],
          applicationID: rumContext.applicationId,
          sessionID: rumContext.sessionId,
          viewID: rumContext.viewId!,
        );
        final expectedJson = jsonEncode(expectedRecord);
        verify(() => mockPlatform.setRecordCount(rumContext.viewId!, 4));
        verify(
          () => mockPlatform.writeSegment(expectedJson, rumContext.viewId!),
        );
      },
    );

    test(
      'process snapshot with change in context produces full snapshot',
      () async {
        // Given
        final newContext = RUMContext(
          applicationId: rumContext.applicationId,
          sessionId: rumContext.sessionId,
          viewId: randomString(),
        );
        final secondMockCapture = MockCaptureNode();
        final mockShape = createMockShapeWireframe(1);
        when(() => secondMockCapture.buildWireframes()).thenReturn([mockShape]);
        final secondTimestamp = firstTimestamp.add(Duration(milliseconds: 200));
        final secondCapture = CaptureResult(
          ViewTreeSnapshot(
            date: secondTimestamp,
            context: newContext,
            viewportSize: Size(600, 800),
            nodes: [secondMockCapture],
          ),
          null,
        );

        // When
        await worker.processSnapshot(secondCapture);

        // Then
        verify(() => mockPlatform.setRecordCount(newContext.viewId!, 3));

        final expectedRecord = SREnrichedRecord(
          records: [
            SRMetaRecord(
              data: SRMetaRecordData(width: 600, height: 800),
              timestamp: secondTimestamp.toUtc().millisecondsSinceEpoch,
            ),
            SRFocusRecord(
              data: SRFocusRecordData(hasFocus: true),
              timestamp: secondTimestamp.toUtc().millisecondsSinceEpoch,
            ),
            SRFullSnapshotRecord(
              data: SRFullSnapshotRecordData(wireframes: [mockShape]),
              timestamp: secondTimestamp.toUtc().millisecondsSinceEpoch,
            ),
          ],
          applicationID: newContext.applicationId,
          sessionID: newContext.sessionId,
          viewID: newContext.viewId!,
        );
        final encodedRecord = jsonEncode(expectedRecord);
        verify(
          () => mockPlatform.writeSegment(encodedRecord, newContext.viewId!),
        );
      },
    );
  });

  group('pointer snapshot', () {
    initializeMockPlatform();

    final mockCapture = MockCaptureNode();

    final mockShape = createMockShapeWireframe(0);
    when(() => mockCapture.buildWireframes()).thenReturn([mockShape]);
    final rumContext = RUMContext(
      applicationId: randomString(),
      sessionId: randomString(),
      viewId: randomString(),
    );
    final firstTimestamp = DateTime.now();

    late ProcessorWorker worker;

    setUp(() async {
      worker = ProcessorWorker();
    });

    test(
      'process snapshot with empty pointer capture sends no pointer record',
      () async {
        // Given
        final firstCapture = CaptureResult(
          ViewTreeSnapshot(
            date: firstTimestamp,
            context: rumContext,
            viewportSize: Size(600, 800),
            nodes: [mockCapture],
          ),
          PointerSnapshot(firstTimestamp, []),
        );

        // When
        await worker.processSnapshot(firstCapture);

        // Sends a Meta, Focus, FullSnapshot, no pointer record
        verify(() => mockPlatform.setRecordCount(rumContext.viewId!, 3));
        verify(() => mockPlatform.writeSegment(any(), any()));
      },
    );

    test(
      'process snapshot with pointer capture sends pointers in snapshot',
      () async {
        // Given
        final pointer = PointerCapture(
          date: firstTimestamp,
          pointerId: 0,
          eventType: SRPointerEventType.down,
          x: randomDouble(),
          y: randomDouble(),
        );
        final firstCapture = CaptureResult(
          ViewTreeSnapshot(
            date: firstTimestamp,
            context: rumContext,
            viewportSize: Size(600, 800),
            nodes: [mockCapture],
          ),
          PointerSnapshot(firstTimestamp, [pointer]),
        );

        // When
        await worker.processSnapshot(firstCapture);

        // Sends a Meta, Focus, FullSnapshot, and Pointer record
        verify(() => mockPlatform.setRecordCount(rumContext.viewId!, 4));

        final expectedRecord = SREnrichedRecord(
          records: [
            SRMetaRecord(
              data: SRMetaRecordData(width: 600, height: 800),
              timestamp: firstTimestamp.toUtc().millisecondsSinceEpoch,
            ),
            SRFocusRecord(
              data: SRFocusRecordData(hasFocus: true),
              timestamp: firstTimestamp.toUtc().millisecondsSinceEpoch,
            ),
            SRFullSnapshotRecord(
              data: SRFullSnapshotRecordData(wireframes: [mockShape]),
              timestamp: firstTimestamp.toUtc().millisecondsSinceEpoch,
            ),
            SRIncrementalSnapshotRecord(
              data: SRPointerInteractionData(
                pointerEventType: pointer.eventType,
                pointerId: pointer.pointerId,
                pointerType: SRPointerType.touch,
                x: pointer.x,
                y: pointer.y,
              ),
              timestamp: pointer.date.millisecondsSinceEpoch,
            ),
          ],
          applicationID: rumContext.applicationId,
          sessionID: rumContext.sessionId,
          viewID: rumContext.viewId!,
        );
        final encodedRecord = jsonEncode(expectedRecord);
        verify(
          () => mockPlatform.writeSegment(encodedRecord, rumContext.viewId!),
        );
      },
    );
  });
}
