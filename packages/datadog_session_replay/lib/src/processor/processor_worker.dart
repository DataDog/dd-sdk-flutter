// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

import '../../datadog_session_replay.dart';
import '../capture/pointer_capture.dart';
import '../capture/recorder.dart';
import '../capture/view_tree_snapshot.dart';
import '../datadog_session_replay_platform_interface.dart';
import '../extensions.dart';
import '../sr_data_models.dart';
import 'diff.dart';
import 'font_family_transform.dart';

/// An internal class that does all of the work for processing a ViewSnapshot into SRRecords,
/// including creating diffs for non full records. When complete, the processor sends
/// the records to the native method channel so they can be serialized and sent to intake.
class ProcessorWorker {
  ProcessorWorker({
    FontFamilyTransformConfig fontFamilyTransform =
        const FontFamilyTransformConfig(),
  }) : _fontTransform = FontFamilyTransform(fontFamilyTransform);

  final FontFamilyTransform _fontTransform;

  ViewTreeSnapshot? _lastSnapshot;
  List<SRWireframe>? _lastWireframes;
  final Map<String, int> _recordCountByViewId = {};

  Future<void> processSnapshot(CaptureResult snapshot) async {
    final viewSnapshot = snapshot.viewTreeSnapshot;
    final viewId = viewSnapshot.context.viewId;
    if (viewId == null) return;

    final wireframes = generateWireframes(snapshot);
    var records = <SRRecord>[];

    final timestamp = viewSnapshot.date.toUtc().millisecondsSinceEpoch;

    if (viewSnapshot.context.applicationId !=
            _lastSnapshot?.context.applicationId ||
        viewSnapshot.context.sessionId != _lastSnapshot?.context.sessionId ||
        viewSnapshot.context.viewId != _lastSnapshot?.context.viewId) {
      // Generate full snapshot
      records.add(
        SRMetaRecord(
          data: SRMetaRecordData(
            width: viewSnapshot.viewportSize.width.safeRound(1),
            height: viewSnapshot.viewportSize.height.safeRound(1),
          ),
          timestamp: timestamp,
        ),
      );
      records.add(
        SRFocusRecord(
          data: SRFocusRecordData(hasFocus: true),
          timestamp: timestamp,
        ),
      );
      records.add(
        SRFullSnapshotRecord(
          data: SRFullSnapshotRecordData(wireframes: wireframes),
          timestamp: timestamp,
        ),
      );
    } else if (_lastWireframes != null) {
      final incrementalRecord = _createIncrementalRecord(
        viewSnapshot,
        wireframes,
        _lastWireframes!,
      );
      if (incrementalRecord != null) {
        records.add(incrementalRecord);
      }
    }

    if (snapshot.pointerSnapshot case final pointerSnapshot?) {
      if (pointerSnapshot.pointerEvents.isNotEmpty) {
        records.addAll(
          pointerSnapshot.pointerEvents.map(_createIncrementalPointerRecord),
        );
      }
    }

    if (records.isNotEmpty) {
      final enrichedRecord = SREnrichedRecord(
        records: records,
        applicationID: viewSnapshot.context.applicationId,
        sessionID: viewSnapshot.context.sessionId,
        viewID: viewId,
      );

      var totalRecordCount = _recordCountByViewId[viewId] ?? 0;
      totalRecordCount += records.length;
      _recordCountByViewId[viewId] = totalRecordCount;
      // We don't have to wait for this to respond before sending the segment. They'll
      // still be processed in order and this gives us more time to perform the encode.
      DatadogSessionReplayPlatform.instance.setRecordCount(
        viewId,
        totalRecordCount,
      );

      try {
        var encoded = jsonEncode(enrichedRecord);
        await DatadogSessionReplayPlatform.instance.writeSegment(
          encoded,
          viewId,
        );
      } catch (e, st) {
        DatadogSessionReplayPlatform.instance.telemetryError(
          'Error writing segment: $e',
          e.runtimeType.toString(),
          st.toString(),
        );
      }
    }

    _lastSnapshot = viewSnapshot;
    _lastWireframes = wireframes;
  }

  @visibleForTesting
  List<SRWireframe> generateWireframes(CaptureResult result) {
    return result.viewTreeSnapshot.nodes
        .expand((element) => element.buildWireframes())
        .map((wireframe) {
      if (wireframe is SRTextWireframe) {
        return _fontTransform.apply(wireframe);
      }
      return wireframe;
    }).toList();
  }

  SRRecord _createIncrementalPointerRecord(PointerCapture pointer) {
    return SRIncrementalSnapshotRecord(
      data: SRPointerInteractionData(
        pointerEventType: pointer.eventType,
        pointerId: pointer.pointerId,
        pointerType: SRPointerType.touch,
        x: pointer.x,
        y: pointer.y,
      ),
      timestamp: pointer.date.millisecondsSinceEpoch,
    );
  }

  SRRecord? _createIncrementalRecord(
    ViewTreeSnapshot viewTreeSnapshot,
    List<SRWireframe> wireframes,
    List<SRWireframe> lastWireframes,
  ) {
    final timestamp = viewTreeSnapshot.date.toUtc().millisecondsSinceEpoch;
    try {
      final diff = computeDiff(lastWireframes, wireframes);
      if (diff.isEmpty) {
        return null;
      }
      return SRIncrementalSnapshotRecord(
        data: SRIncrementalMutationData(
          adds: diff.adds,
          removes: diff.removes,
          updates: diff.updates,
        ),
        timestamp: timestamp,
      );
    } catch (_) {
      // default back to full snaposhot
      return SRFullSnapshotRecord(
        data: SRFullSnapshotRecordData(wireframes: wireframes),
        timestamp: timestamp,
      );
    }
  }
}
