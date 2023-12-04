// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../capture/view_tree_snapshot.dart';
import '../datadog_session_replay_platform_interface.dart';
import '../sr_data_models.dart';
import 'diff.dart';

class SessionReplayProcessor {
  final ReceivePort _mainReceivePort = ReceivePort('sr-replay-port');
  SendPort? _mainSendPort;

  Future<void> start() async {
    await Isolate.spawn(
      _captureProcessor,
      _ProcessorArgs(RootIsolateToken.instance!, _mainReceivePort.sendPort),
    );

    _mainSendPort = await _mainReceivePort.first;
  }

  void process(ViewTreeSnapshot viewTreeSnapshot) {
    _mainSendPort?.send(viewTreeSnapshot);
  }

  static Future<void> _captureProcessor(_ProcessorArgs args) async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootIsolateToken);
    final ReceivePort commandPort = ReceivePort();
    final responsePort = args.sendPort;
    responsePort.send(commandPort.sendPort);

    final internalProcessor = _InternalProcessor();

    await for (final message in commandPort) {
      if (message is ViewTreeSnapshot) {
        await internalProcessor.processSnapshot(message);
      } else if (message == null) {
        break;
      }
    }

    Isolate.exit();
  }
}

class _InternalProcessor {
  ViewTreeSnapshot? lastSnapshot;
  List<SRWireframe>? lastWireframes;
  final Map<String, int> _recordCountByViewId = {};

  Future<void> processSnapshot(ViewTreeSnapshot snapshot) async {
    final viewId = snapshot.context.viewId;
    if (viewId == null) return;

    final wireframes = snapshot.nodes
        .expand((element) => element.wireframeBuilder.buildWireframes(element))
        .toList();

    var records = <SRRecord>[];

    final timestamp = snapshot.date.toUtc().millisecondsSinceEpoch;

    // TODO: Check if anything changed and do an incremental record
    if (snapshot.context.applicationId != lastSnapshot?.context.applicationId ||
        snapshot.context.sessionId != lastSnapshot?.context.sessionId ||
        snapshot.context.viewId != lastSnapshot?.context.viewId) {
      // Generate full snapshot
      records.add(
        SRMetaRecord(
          data: SRMetaRecordData(
              width: snapshot.viewportSize.width.toInt(),
              height: snapshot.viewportSize.height.toInt()),
          timestamp: timestamp,
        ),
      );
      records.add(SRFocusRecord(
          data: SRFocusRecordData(hasFocus: true), timestamp: timestamp));
      records.add(SRFullSnapshotRecord(
          data: SRFullSnapshotRecordData(wireframes: wireframes),
          timestamp: timestamp));
    } else if (lastWireframes != null) {
      final incrementalRecord =
          _createIncrementalRecord(snapshot, wireframes, lastWireframes!);
      if (incrementalRecord != null) {
        records.add(incrementalRecord);
      }
    }

    if (records.isNotEmpty) {
      final enrichedRecord = SREnrichedRecord(
        records: records,
        applicationID: snapshot.context.applicationId,
        sessionID: snapshot.context.sessionId,
        viewID: viewId,
        hasFullSnapshot: true,
        earliestTimestamp: timestamp,
        latestTimestamp: timestamp,
      );

      var totalRecordCount = _recordCountByViewId[viewId] ?? 0;
      totalRecordCount += records.length;
      _recordCountByViewId[viewId] = totalRecordCount;
      await DatadogSessionReplayPlatform.instance
          .setRecordCount(viewId, totalRecordCount);

      var encoded = jsonEncode(enrichedRecord.toJson());
      await DatadogSessionReplayPlatform.instance.writeSegment(encoded, viewId);
    }

    lastSnapshot = snapshot;
    lastWireframes = wireframes;
  }

  SRRecord? _createIncrementalRecord(ViewTreeSnapshot viewTreeSnapshot,
      List<SRWireframe> wireframes, List<SRWireframe> lastWireframes) {
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

@immutable
class _ProcessorArgs {
  final RootIsolateToken rootIsolateToken;
  final SendPort sendPort;

  const _ProcessorArgs(this.rootIsolateToken, this.sendPort);
}
