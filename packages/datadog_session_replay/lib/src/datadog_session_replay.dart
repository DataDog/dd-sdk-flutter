// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../datadog_session_replay.dart';
import 'capture/capture_node.dart';
import 'capture/element_recorders/text_recorder.dart';
import 'capture/view_tree_snapshot.dart';
import 'datadog_session_replay_platform_interface.dart';
import 'sr_data_models.dart';

class KeyGenerator {
  // This is close to JavaScript's MAX_SAFE_INT (53-bit)
  static const int maxKey = 0x20000000000000;
  var nextKey = 0;

  final Expando<int> _expando = Expando('sr-keys');

  int keyForElement(Element e) {
    var value = _expando[e];
    if (value != null) return value;

    value = nextKey;
    nextKey = nextKey + 1;
    if (nextKey >= maxKey) nextKey = 0;

    return value;
  }
}

class DatadogSessionReplay {
  static DatadogSessionReplay? _instance;
  static DatadogSessionReplay? get instance => _instance;

  final DatadogSessionReplayConfiguration _configuration;

  final Map<Key, Element> _elements = {};
  final List<ElementRecorder> _elementRecorders = [
    TextElementRecorder(),
  ];

  RUMContext? _currentContext;
  ReceivePort? _mainReceivePort;
  SendPort? _mainSendPort;

  @internal
  static Future<void> init(
      DatadogSessionReplayConfiguration configuration) async {
    _instance = DatadogSessionReplay._(configuration);
    await _instance!.start();
  }

  DatadogSessionReplay._(this._configuration);

  void addElement(Key key, Element e) {
    _elements[key] = e;
  }

  void removeElement(Key? key) {
    _elements.remove(key);
  }

  Future<void> start() async {
    final platform = DatadogSessionReplayPlatform.instance;
    await platform.enable(_configuration, _onContextChanged);

    _mainReceivePort = ReceivePort();
    await Isolate.spawn(
      _captureProcessor,
      _ProcessorArgs(RootIsolateToken.instance!, _mainReceivePort!.sendPort),
    );

    _mainSendPort = await _mainReceivePort!.first;
  }

  void performCapture() {
    final context = _currentContext;
    if (context == null) {
      return;
    }

    DateTime now = DateTime.now();
    List<CaptureNode> nodes = [];
    var size = Size.zero;
    for (final e in _elements.values) {
      final elementSize = e.size;
      if (elementSize != null) {
        // Need to copy this value because the size class
        // returned by the element is not serializable over the isolate
        size = Size(elementSize.width, elementSize.height);
      }
      _captureElement(e, nodes);
    }

    if (nodes.isNotEmpty) {
      final viewTreeCapture = ViewTreeSnapshot(
        date: now,
        context: context,
        viewportSize: size,
        nodes: nodes,
      );

      _mainSendPort?.send(viewTreeCapture);
    }
  }

  void _onContextChanged(RUMContext context) {
    _currentContext = context;

    DatadogSessionReplayPlatform.instance.setHasReplay(context.viewId != null);
  }

  void _captureElement(Element topElement, List<CaptureNode> nodes) {
    final stopwatch = Stopwatch();
    stopwatch.start();

    void visit(Element e, int depth) {
      final renderObject = e.renderObject;
      if (renderObject == null) return;

      final transformMatrix =
          renderObject.getTransformTo(topElement.renderObject);
      final paintBounds =
          MatrixUtils.transformRect(transformMatrix, renderObject.paintBounds);
      final viewAttributes = CapturedViewAttributes(paintBounds: paintBounds);

      final elementSemantics = _elementSemantics(e, viewAttributes);

      nodes.addAll(elementSemantics.nodes);

      if (elementSemantics.subtreeStrategy ==
          CaptureNodeSubtreeStrategy.record) {
        e.visitChildElements((child) {
          final renderObject = child.renderObject;
          if (renderObject == null) return;

          visit(child, depth + 1);
        });
      }
    }

    visit(topElement, 0);

    stopwatch.stop();
  }

  CaptureNodeSemantics _elementSemantics(
      Element element, CapturedViewAttributes viewAttributes) {
    CaptureNodeSemantics semantics = const UnknownElement();

    for (final recorder in _elementRecorders) {
      final nextSemantics = recorder.captureSemantics(element, viewAttributes);
      if (nextSemantics == null) continue;

      if (nextSemantics.importance >= semantics.importance) {
        semantics = nextSemantics;
        if (semantics.importance == CaptureNodeSemantics.maxImporance) {
          break;
        }
      }
    }

    return semantics;
  }
}

@immutable
class RUMContext {
  final String applicationId;
  final String sessionId;
  final String? viewId;
  final double? viewServerTimeOffset;

  const RUMContext({
    required this.applicationId,
    required this.sessionId,
    this.viewId,
    this.viewServerTimeOffset,
  });

  factory RUMContext.fromMap(Map<Object?, Object?> map) {
    return RUMContext(
      applicationId: map['applicationId'] as String,
      sessionId: map['sessionId'] as String,
      viewId: map['viewId'] as String?,
      viewServerTimeOffset: map['viewServerTimeOffset'] as double?,
    );
  }
}

@immutable
class _ProcessorArgs {
  final RootIsolateToken rootIsolateToken;
  final SendPort sendPort;

  const _ProcessorArgs(this.rootIsolateToken, this.sendPort);
}

Future<void> _captureProcessor(_ProcessorArgs args) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootIsolateToken);
  final ReceivePort commandPort = ReceivePort();
  final responsePort = args.sendPort;
  responsePort.send(commandPort.sendPort);

  await for (final message in commandPort) {
    if (message is ViewTreeSnapshot) {
      await _processSnapshot(message);
    } else if (message == null) {
      break;
    }
  }

  Isolate.exit();
}

// TODO: Enclose this in a class
Map<String, int> _recordCountByViewId = {};

Future<void> _processSnapshot(ViewTreeSnapshot snapshot) async {
  final viewId = snapshot.context.viewId;
  if (viewId == null) return;

  final wireframes = snapshot.nodes
      .expand((element) => element.wireframeBuilder.buildWireframes(element))
      .toList();

  var records = <SRRecord>[];

  final timestamp = snapshot.date.toUtc().microsecondsSinceEpoch;

  // TODO: Check if anything changed and do an incremental record
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
}
