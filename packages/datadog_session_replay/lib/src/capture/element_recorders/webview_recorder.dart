// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/widgets.dart';

import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../view_tree_snapshot.dart';

/// Records a `webview_flutter` WebView (on iOS, a [UiKitView] whose
/// `creationParams` is the WebView's identifier) as a `webview` wireframe, so
/// the replay player draws the WebView's Browser SDK replay inside it.
///
/// Only WebViews tracked with `trackDatadogEvents` have a slot ID; others fall
/// through to the default recording, as before.
@immutable
class WebViewRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;
  final WebViewSlotTracker slotTracker;

  const WebViewRecorder(this.keyGenerator, this.slotTracker);

  @override
  bool accepts(Widget widget) =>
      widget is UiKitView && widget.viewType == webViewPlatformViewType;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! UiKitView) return null;

    final identifier = widget.creationParams;
    if (identifier is! int) return null;

    final slotId = WebViewSlotRegistry.slotId(identifier);
    if (slotId == null) return null;

    slotTracker.markVisible(slotId);
    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: [
        VisibleWebViewNode(
          attributes,
          wireframeId: keyGenerator.keyForWebViewSlot(slotId),
          slotId: slotId,
        ),
      ],
    );
  }
}

/// Tracks which WebView slots were recorded, so a WebView that leaves the
/// screen while still alive is recorded as hidden instead of disappearing.
/// The player needs the hidden wireframe to stop drawing that WebView's replay.
class WebViewSlotTracker {
  final KeyGenerator keyGenerator;

  final Set<String> _recordedSlotIds = {};
  final Set<String> _visibleSlotIds = {};

  WebViewSlotTracker(this.keyGenerator);

  /// Call before walking the tree for a new capture.
  void beginCapture() => _visibleSlotIds.clear();

  void markVisible(String slotId) {
    _recordedSlotIds.add(slotId);
    _visibleSlotIds.add(slotId);
  }

  /// Hidden wireframes for slots recorded before but not visible in this
  /// capture. Slots whose WebView was collected are forgotten, so they stop
  /// being recorded at all.
  List<CaptureNode> hiddenSlotNodes() {
    _recordedSlotIds.removeWhere(
      (slotId) => !WebViewSlotRegistry.isRegistered(slotId),
    );
    return [
      for (final slotId in _recordedSlotIds.difference(_visibleSlotIds))
        HiddenWebViewNode(
          wireframeId: keyGenerator.keyForWebViewSlot(slotId),
          slotId: slotId,
        ),
    ];
  }
}

@immutable
class VisibleWebViewNode extends CaptureNode {
  final int wireframeId;
  final String slotId;

  const VisibleWebViewNode(
    super.attributes, {
    required this.wireframeId,
    required this.slotId,
  });

  @override
  List<SRWireframe> buildWireframes() {
    return [
      SRWebviewWireframe(
        id: wireframeId,
        x: attributes.x,
        y: attributes.y,
        width: attributes.width,
        height: attributes.height,
        slotId: slotId,
      ),
    ];
  }
}

@immutable
class HiddenWebViewNode extends CaptureNode {
  final int wireframeId;
  final String slotId;

  const HiddenWebViewNode({required this.wireframeId, required this.slotId})
    : super(
        const CapturedViewAttributes(
          paintBounds: Rect.zero,
          scaleX: 1,
          scaleY: 1,
        ),
      );

  @override
  List<SRWireframe> buildWireframes() {
    return [
      SRWebviewWireframe(
        id: wireframeId,
        x: 0,
        y: 0,
        width: 0,
        height: 0,
        slotId: slotId,
        isVisible: false,
      ),
    ];
  }
}
