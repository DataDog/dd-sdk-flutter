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
  // This is close to JavaScript's MAX_SAFE_INT (52-bit)
  static const int maxKey = 0xFFFFFFFFFFFFF;
  var nextKey = 0;

  final Expando<int> _expando = Expando('sr-keys');

  int keyForElement(Element e) {
    var value = _expando[e];
    if (value != null) return value;

    value = nextKey;
    nextKey = nextKey + 1;
    if (nextKey > maxKey) nextKey = 0;

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
    final capturedElements = _elements.values
        .map((e) {
          return _captureElement(e);
        })
        .whereType<CaptureNode>()
        .toList();
    if (capturedElements.isNotEmpty) {
      final viewTreeCapture = ViewTreeSnapshot(
        date: now,
        context: context,
        viewportSize: const Size(1000.0, 1000.0),
        nodes: capturedElements,
      );

      _mainSendPort?.send(viewTreeCapture);
    }
  }

  void _onContextChanged(RUMContext context) {
    _currentContext = context;
  }

  CaptureNode? _captureElement(Element topElement) {
    final stopwatch = Stopwatch();
    stopwatch.start();

    CaptureNode? visit(Element e, int depth) {
      final renderObject = e.renderObject;
      if (renderObject == null) return null;

      final transformMatrix =
          renderObject.getTransformTo(topElement.renderObject);
      final paintBounds =
          MatrixUtils.transformRect(transformMatrix, renderObject.paintBounds);
      final viewAttributes = CapturedViewAttributes(paintBounds: paintBounds);

      CaptureNode? node;
      for (final recorder in _elementRecorders) {
        final captured = recorder.captureElement(e, viewAttributes);
        if (captured != null) {
          node = captured;
          break;
        }
      }

      // TODO: Semantics to prevent recursion
      //if (node != null) {
      e.visitChildElements((child) {
        final renderObject = child.renderObject;
        if (renderObject == null) return;

        final childNode = visit(child, depth + 1);
        if (childNode != null) {
          if (node == null) {
            node = childNode;
          } else {
            node!.addChild(childNode);
          }
        }
      });
      //}

      return node;
    }

    final node = visit(topElement, 0);

    stopwatch.stop();

    return node;
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
      viewID: snapshot.context.viewId!,
      hasFullSnapshot: true,
      earliestTimestamp: timestamp,
      latestTimestamp: timestamp,
    );
    var encoded = jsonEncode(enrichedRecord.toJson());
    await DatadogSessionReplayPlatform.instance.writeSegment(encoded, viewId);
  }
}
