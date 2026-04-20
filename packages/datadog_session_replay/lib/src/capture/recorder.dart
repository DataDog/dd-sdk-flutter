// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:developer';
import 'dart:ui' as ui;

import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../datadog_session_replay.dart';
import '../datadog_session_replay_platform_interface.dart';
import '../rum_context.dart';
import '../widgets.dart';
import 'capture_node.dart';
import 'element_recorders/container_recorder.dart';
import 'element_recorders/custom_paint_recorder.dart';
import 'element_recorders/editable_text_recorder.dart';
import 'element_recorders/icon_recorder.dart';
import 'element_recorders/image_recorder.dart';
import 'element_recorders/privacy_recorder.dart';
import 'element_recorders/text_recorder.dart';
import 'pointer_capture.dart';
import 'view_tree_snapshot.dart';

/// Capture privacy for the current tree of nodes. This is set by the configuration,
/// to start, but can change if the capture encounters a Widget that modifies it.
@immutable
class TreeCapturePrivacy {
  final TextAndInputPrivacyLevel textAndInputPrivacyLevel;
  final ImagePrivacyLevel imagePrivacyLevel;

  const TreeCapturePrivacy({
    required this.textAndInputPrivacyLevel,
    required this.imagePrivacyLevel,
  });

  @override
  bool operator ==(Object other) {
    if (other is! TreeCapturePrivacy) return false;

    return other.textAndInputPrivacyLevel == textAndInputPrivacyLevel &&
        other.imagePrivacyLevel == imagePrivacyLevel;
  }

  @override
  int get hashCode {
    return textAndInputPrivacyLevel.hashCode;
  }
}

abstract interface class ElementRecorder {
  List<Type> get handlesTypes;

  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  );
}

class KeyGenerator {
  // This is close to JavaScript's MAX_SAFE_INT (53-bit)
  static const int maxKey = 0x20000000000000;
  // Starting key for resources
  static const int startingResourceKey = 0x100000;

  var _nextElementKey = 0;
  var _nextResourceKey = startingResourceKey;

  final Expando<int> _nodeIdExpando = Expando('sr-key');
  final Expando<int> _resourceIdExpando = Expando('sr-resource-key');

  int keyForElement(Element e) {
    var value = _nodeIdExpando[e];
    if (value != null) return value;

    value = _nextElementKey;
    _nextElementKey = _nextElementKey + 1;
    if (_nextElementKey >= maxKey) _nextElementKey = 0;

    _nodeIdExpando[e] = value;

    return value;
  }

  bool hasImageKey(ui.Image e) => _resourceIdExpando[e] != null;

  int keyForImage(ui.Image e) {
    var value = _resourceIdExpando[e];
    if (value != null) return value;

    value = _nextResourceKey;
    _nextResourceKey = _nextResourceKey + 1;
    if (_nextResourceKey >= maxKey) _nextResourceKey = startingResourceKey;

    _resourceIdExpando[e] = value;
    return value;
  }
}

@immutable
class CaptureResult {
  final ViewTreeSnapshot viewTreeSnapshot;
  final PointerSnapshot? pointerSnapshot;

  const CaptureResult(this.viewTreeSnapshot, this.pointerSnapshot);
}

class SessionReplayRecorder {
  final DatadogTimeProvider _timeProvider;
  final Map<Type, ElementRecorder> _elementRecordersByType = {};

  final Map<Key, Element> _elements = {};
  RUMContext? _currentContext;
  bool _captureInProgress = false;
  TreeCapturePrivacy _defaultTreeCapturePrivacy;
  // TODO(RUM-11681): Support touch privacy
  // ignore: unused_field
  TouchPrivacyLevel _touchPrivacyLevel;

  @visibleForTesting
  set defaultTreeCapturePrivacy(TreeCapturePrivacy value) =>
      _defaultTreeCapturePrivacy = value;
  TreeCapturePrivacy get defaultTreeCapturePrivacy =>
      _defaultTreeCapturePrivacy;

  SessionReplayRecorder({
    DatadogTimeProvider timeProvider = const DefaultTimeProvider(),
    required TreeCapturePrivacy defaultCapturePrivacy,
    required TouchPrivacyLevel touchPrivacyLevel,
    double iconRasterLogicalSize = 20.0,
    InternalLogger? internalLogger,
  }) : this._(
          KeyGenerator(),
          timeProvider,
          defaultCapturePrivacy,
          touchPrivacyLevel,
          iconRasterLogicalSize,
          internalLogger,
        );

  SessionReplayRecorder._(
    KeyGenerator keyGenerator,
    this._timeProvider,
    this._defaultTreeCapturePrivacy,
    this._touchPrivacyLevel,
    double iconRasterLogicalSize,
    InternalLogger? internalLogger,
  ) {
    _populateElementRecorderMap([
      ContainerRecorder(keyGenerator),
      TextElementRecorder(keyGenerator),
      IconRecorder(
        keyGenerator,
        internalLogger: internalLogger,
        iconRasterLogicalSize: iconRasterLogicalSize,
      ),
      EditableTextRecorder(keyGenerator),
      InputDecoratorRecorder(keyGenerator),
      ImageRecorder(keyGenerator),
      CustomPaintRecorder(keyGenerator),
      PrivacyRecorder(keyGenerator),
    ]);
  }

  @visibleForTesting
  SessionReplayRecorder.withCustomRecorders(
    List<ElementRecorder> elementRecorders, {
    DatadogTimeProvider timeProvider = const DefaultTimeProvider(),
    required TreeCapturePrivacy defaultCapturePrivacy,
    required TouchPrivacyLevel touchPrivacyLevel,
  })  : _timeProvider = timeProvider,
        _defaultTreeCapturePrivacy = defaultCapturePrivacy,
        _touchPrivacyLevel = touchPrivacyLevel {
    _populateElementRecorderMap(elementRecorders);
  }

  void updateContext(RUMContext? context) {
    _currentContext = context;
  }

  void addElement(Key key, Element e) {
    _elements[key] = e;
  }

  void removeElement(Key key) {
    _elements.remove(key);
  }

  Future<CaptureResult?> performCapture() async {
    final context = _currentContext;
    if (context == null) {
      return null;
    }

    // We're currently in the middle of a capture (async processing is still
    // occurring), don't start another frame until this one is done.
    if (_captureInProgress) return null;

    _captureInProgress = true;
    List<CaptureNodeSemantics> capturedSemantics = [];
    List<PointerSnapshot> pointerSnapshots = [];
    DateTime now = _timeProvider.now();
    var size = Size.zero;

    Timeline.timeSync('Datadog SR Tree Capture', () {
      for (final e in _elements.values) {
        final renderObject = e.renderObject;
        if (kDebugMode) {
          // During hot reload, elements can be inserted that still need layout, and
          // these will throw when we get their size. Avoid capturing these
          if (renderObject?.debugNeedsLayout == true) continue;
        }

        /// This shouldn't happen as we now remove widgets from capture requests during
        /// dispose. But, just in case, let's skip any widgets that are in a defunct state.
        if (!e.mounted) continue;

        // In debug mode, Flutter will assert if you attempt to access the size of an
        // object that shouldn't have size. We can skip elements that have no size for
        // whatever reason.
        if (renderObject is RenderBox && !renderObject.hasSize) continue;

        final elementSize = e.size;
        if (elementSize != null) {
          // Need to copy this value because the size class
          // returned by the element is not serializable over the isolate
          size = Size(elementSize.width, elementSize.height);
        }
        _captureElement(
          e,
          capturedSemantics,
          pointerSnapshots,
          _defaultTreeCapturePrivacy,
        );
      }
    });

    final addedProcessingTimelineTask = TimelineTask()
      ..start('Datadog SR Capture Processing');

    // Process anything that needs additional processing (parallelize so
    // multiple icons/images don't serialize their async work).
    final nodes = <CaptureNode>[];
    final resolved = await Future.wait(
      capturedSemantics.map((s) async {
        if (s is AdditionalProcessingElement) {
          try {
            return await s.process();
          } catch (e, st) {
            DatadogSessionReplayPlatform.instance.telemetryError(
              'Exception during session replay capture: $e',
              e.runtimeType.toString(),
              st.toString(),
            );
            return null;
          }
        }
        return s;
      }),
    );
    for (final s in resolved) {
      if (s != null) {
        nodes.addAll(s.nodes);
      }
    }
    addedProcessingTimelineTask.finish();

    _captureInProgress = false;

    if (nodes.isEmpty) return null;

    final viewTreeSnapshot = ViewTreeSnapshot(
      date: now,
      context: context,
      viewportSize: size,
      nodes: nodes,
    );

    // We shouldn't have multiple pointer snapshots, but even if we
    // do, for now just take the first one.
    final pointerSnapshot = pointerSnapshots.firstOrNull;

    return CaptureResult(viewTreeSnapshot, pointerSnapshot);
  }

  void onContextChanged(RUMContext context) {
    _currentContext = context;

    if (context.viewId case final viewId?) {
      DatadogSessionReplayPlatform.instance.setHasReplay(viewId, true);
    }
  }

  void _populateElementRecorderMap(List<ElementRecorder> recorders) {
    for (final recorder in recorders) {
      for (final type in recorder.handlesTypes) {
        _elementRecordersByType[type] = recorder;
      }
    }
  }

  // Certain elements will cause everything under the element to be invisible, such
  // as Visibility or FadeTransition. Ignore these trees.
  bool _shouldIgnoreTree(Element e) {
    final widget = e.widget;
    switch (widget) {
      case final Visibility visibility:
        if (!visibility.visible) return true;
        break;
      case final SliverVisibility visibility:
        if (!visibility.visible) return true;
        break;
      case final FadeTransition transition:
        if (transition.opacity.value <= 0.0) return true;
        break;
    }

    return false;
  }

  void _captureElement(
    Element topElement,
    List<CaptureNodeSemantics> capturedSemantics,
    List<PointerSnapshot> pointerSnapshots,
    TreeCapturePrivacy capturePrivacy,
  ) {
    void visit(Element e, TreeCapturePrivacy capturePrivacy, int depth) {
      if (e.widget case final PointerRecorder snapshotWidget) {
        if (snapshotWidget.pointerRecorder.takeSnapshot()
            case final snapshot?) {
          pointerSnapshots.add(snapshot);
        }
      }

      if (_shouldIgnoreTree(e)) return;

      final renderObject = e.renderObject;
      if (renderObject == null) return;

      // TODO(RUM-10473): debugNeedsLayout is also set during scrolling and does not throw from
      // the recorder, so we'll need to look for a different flag to prevent the throw
      // during hot reload.
      // During hot reload, the recorder can try to capture items that still need
      // layout, which will throw. Prevent this.
      // if (kDebugMode && renderObject.debugNeedsLayout) {
      //   return;
      // }

      final untransformedPaintBounds = renderObject.paintBounds;
      // Don't capture things that take up no space.
      if (untransformedPaintBounds.width == 0 ||
          untransformedPaintBounds.height == 0) {
        return;
      }

      final widget = e.widget;
      final recorder = _elementRecordersByType[widget.runtimeType];
      var subtreeStrategy = CaptureNodeSubtreeStrategy.record;
      if (recorder != null) {
        final transformMatrix = renderObject.getTransformTo(
          topElement.renderObject,
        );

        final paintBounds = MatrixUtils.transformRect(
          transformMatrix,
          renderObject.paintBounds,
        );

        final scaleX = paintBounds.width / untransformedPaintBounds.width;
        final scaleY = paintBounds.height / untransformedPaintBounds.height;
        final viewAttributes = CapturedViewAttributes(
          paintBounds: paintBounds,
          scaleX: scaleX,
          scaleY: scaleY,
        );
        final semantics = recorder.captureSemantics(
          e,
          viewAttributes,
          capturePrivacy,
        );

        if (semantics != null) {
          subtreeStrategy = semantics.subtreeStrategy;
          if (semantics.subtreePrivacy case final newCapturePrivacy?) {
            capturePrivacy = newCapturePrivacy;
          }

          capturedSemantics.add(semantics);
        }
      }

      if (subtreeStrategy == CaptureNodeSubtreeStrategy.record) {
        e.visitChildElements((child) {
          final renderObject = child.renderObject;
          if (renderObject == null) return;

          visit(child, capturePrivacy, depth + 1);
        });
      }
    }

    visit(topElement, capturePrivacy, 0);
  }
}
