// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:typed_data';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/processor/processor_worker.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/capture/simple_test_capture.dart';
import 'snapshot_renderer.dart';

typedef TestActions = Future<void> Function();

/// Tolerant file comparator pulled directly from the documentation
/// for goldens.  Allows a certain amount of tolerance on golden images,
/// which can happen if images are generated on a different version OS,
/// or on different versions of the same OS.
///
/// Because our goldens are very simple, small differences are unlikely to
/// be flagging an actual bug.
class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  })  : assert(
          0 <= precisionTolerance && precisionTolerance <= 1,
          'precisionTolerance must be between 0 and 1',
        ),
        _precisionTolerance = precisionTolerance;

  /// How much the golden image can differ from the test image.
  ///
  /// It is expected to be between 0 and 1. Where 0 is no difference (the same image)
  /// and 1 is the maximum difference (completely different images).
  final double _precisionTolerance;
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final bool passed =
        result.passed || result.diffPercent <= _precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }
    final String error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

Future<void> snapshotTest(
  WidgetTester tester,
  SessionReplayRecorder recorder,
  Widget fixture, {
  TestActions? testActions,
}) async {
  DatadogSdk.instance.sdkVerbosity = CoreLoggerLevel.debug;
  final processor = ProcessorWorker();
  await tester.pumpWidget(
    SimpleTestCapture(key: Key('key'), recorder: recorder, child: fixture),
  );
  await tester.pumpAndSettle();
  await testActions?.call();
  final previousGoldenFileComparator = goldenFileComparator;
  goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.parse('golden_test/golden_test_helpers.dart'),
      // Allow about a 1% difference. More than that and something broke.
      precisionTolerance: 0.01);
  addTearDown(() => goldenFileComparator = previousGoldenFileComparator);

  List<SRWireframe> wireframes = [];
  await tester.runAsync(() async {
    final capture = await recorder.performCapture();
    // This is a test so safe to ignore invalid use lint
    // ignore: invalid_use_of_visible_for_testing_member
    wireframes = processor.generateWireframes(capture!);
  });

  await tester.pumpWidget(
    CustomPaint(painter: WireframeCustomPainter(wireframes)),
  );
  await tester.pumpAndSettle();
  final goldenName = tester.testDescription.toLowerSnakeCase();
  await expectLater(
    find.byType(CustomPaint),
    matchesGoldenFile('goldens/$goldenName.png'),
  );
}

extension on String {
  String toLowerSnakeCase() {
    return toLowerCase().replaceAll(' ', '_');
  }
}
