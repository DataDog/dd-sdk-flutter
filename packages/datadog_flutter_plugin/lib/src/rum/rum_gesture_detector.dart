// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../../datadog_flutter_plugin.dart';

/// Experimental - will likely be removed in the final release of the gesture
/// detector Determines which version of the element detector to use - walking
/// the Semantic tree or walking the Element tree. This is so we can measure the
/// performance impact of each.
enum ElementDetectionMethod {
  elementTree,
  semanticTree,
}

// The distance a 'pointer' can move and still be considered a tap.
const _tapSlop = 20;
const _tapSlopSquared = _tapSlop * _tapSlop;

@immutable
class _CandidateElementDescription {
  final Element element;
  final String description;

  const _CandidateElementDescription(this.element, this.description);
}

class RumGestureDetector extends StatefulWidget {
  @internal
  static final elementMap = <RumGestureDetector, Element>{};

  final DdRum? rum;
  final Widget child;
  final ElementDetectionMethod elementDetectionMethod;

  const RumGestureDetector({
    Key? key,
    required this.rum,
    required this.child,
    this.elementDetectionMethod = ElementDetectionMethod.elementTree,
  }) : super(key: key);

  @override
  StatefulElement createElement() {
    final e = super.createElement();
    elementMap[this] = e;
    return e;
  }

  @override
  State<RumGestureDetector> createState() => _RumGestureDetectorState();
}

class _RumGestureDetectorState extends State<RumGestureDetector> {
  final _listenerKey = GlobalKey();

  PipelineOwner? _pipelineOwner;
  SemanticsHandle? _semanticsHandle;

  int? _lastPointerId;
  Offset? _lastPointerDownLocation;

  @override
  void initState() {
    super.initState();
    if (widget.elementDetectionMethod == ElementDetectionMethod.semanticTree) {
      _createSemanticsClient();
    }
  }

  @override
  void didUpdateWidget(covariant RumGestureDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    var element = RumGestureDetector.elementMap[oldWidget];
    if (element != null) {
      RumGestureDetector.elementMap.remove(oldWidget);
      RumGestureDetector.elementMap[widget] = element;
    } else {
      // Telemetry -- this shouldn't happen
    }

    if (widget.elementDetectionMethod != ElementDetectionMethod.semanticTree) {
      // Remove semantic client so the app stops updating it
      _disposeSemanticClient();
    } else if (_semanticsHandle == null) {
      _createSemanticsClient();
    }
  }

  @override
  void dispose() {
    _disposeSemanticClient();
    RumGestureDetector.elementMap.remove(widget);
    super.dispose();
  }

  void _disposeSemanticClient() {
    _semanticsHandle?.dispose();
    _semanticsHandle = null;
    _pipelineOwner = null;
  }

  void _createSemanticsClient() {
    _pipelineOwner = WidgetsBinding.instance.pipelineOwner;
    _semanticsHandle = _pipelineOwner!.ensureSemantics();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: _listenerKey,
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      child: widget.child,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _lastPointerId = event.pointer;
    _lastPointerDownLocation = event.localPosition;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_lastPointerDownLocation != null && event.pointer == _lastPointerId) {
      final distanceOffset = Offset(
          _lastPointerDownLocation!.dx - event.localPosition.dx,
          _lastPointerDownLocation!.dy - event.localPosition.dy);

      final distanceSquared = distanceOffset.distanceSquared;
      if (distanceSquared < _tapSlopSquared) {
        _onPerformActionAt(event.localPosition, RumUserActionType.tap);
      }
    }
  }

  void _onPerformActionAt(Offset position, RumUserActionType action) {
    String? elementDescription;

    switch (widget.elementDetectionMethod) {
      case ElementDetectionMethod.elementTree:
        final span = DatadogSdk.instance.traces
            ?.startSpan('GestureRecognizer: ElementTree');
        span?.setActive();
        var detectingElement = _getDetectingElementAtPosition(position);
        if (detectingElement != null) {
          elementDescription = _findElementInnerText(detectingElement.element);
          elementDescription =
              '${detectingElement.description}($elementDescription)';
        }
        span?.finish();
        break;
      case ElementDetectionMethod.semanticTree:
        final rootSemantics = _pipelineOwner?.semanticsOwner?.rootSemanticsNode;
        if (rootSemantics != null) {
          final span = DatadogSdk.instance.traces
              ?.startSpan('GestureRecognizer: SemanticTree');
          span?.setActive();
          position = position * WidgetsBinding.instance.window.devicePixelRatio;

          final data = _getSemanticsDataAtPosition(rootSemantics, position);
          if (data != null) {
            elementDescription =
                data.label.isNotEmpty ? data.label : '(unknown)';
          }
          span?.finish();
        } else {
          // TELEMETRY - Report missing root semantics
        }
        break;
    }

    if (elementDescription != null) {
      widget.rum?.addUserAction(RumUserActionType.tap, elementDescription);
    }
  }

  String _findElementInnerText(Element element) {
    var elementDescription = 'unknown';

    void visitor(Element element) {
      var widget = element.widget;
      if (widget is Text) {
        elementDescription = widget.data ?? 'unknown';
      } else if (widget is Icon) {
        elementDescription = widget.semanticLabel ?? widget.icon.toString();
      } else {
        element.visitChildren(visitor);
      }
    }

    element.visitChildren(visitor);

    return elementDescription;
  }

  _CandidateElementDescription? _getDetectingElementAtPosition(
      Offset position) {
    var rootElement = RumGestureDetector.elementMap[widget];
    if (rootElement == null) return null;

    _CandidateElementDescription? candidateElement;

    void elementVisitor(Element element) {
      final ro = element.renderObject;
      if (ro == null) return;

      final transform = ro.getTransformTo(rootElement.renderObject);
      final paintBounds = MatrixUtils.transformRect(transform, ro.paintBounds);

      if (paintBounds.contains(position)) {
        final widget = element.widget;
        final widgetDescription = _widgetIsEnabledButtonType(widget);
        if (widgetDescription != null) {
          candidateElement =
              _CandidateElementDescription(element, widgetDescription);
        } else {
          element.visitChildElements(elementVisitor);
        }
      }
    }

    rootElement.visitChildElements(elementVisitor);

    return candidateElement;
  }

  String? _widgetIsEnabledButtonType(Widget widget) {
    if (widget is ButtonStyleButton) {
      return widget.enabled ? 'Button' : null;
    } else if (widget is MaterialButton) {
      return widget.enabled ? 'Button' : null;
    } else if (widget is CupertinoButton) {
      return widget.enabled ? 'Button' : null;
    } else if (widget is InkWell) {
      return widget.onTap != null ? 'InkWell' : null;
    } else if (widget is IconButton) {
      return widget.onPressed != null ? 'IconButton' : null;
    } else if (widget is GestureDetector) {
      return widget.onTap != null ? 'GestureDetector' : null;
    }

    return null;
  }

  SemanticsData? _getSemanticsDataAtPosition(
      SemanticsNode node, Offset position) {
    if (node.transform != null) {
      final Matrix4 inverse = Matrix4.identity();
      if (inverse.copyInverse(node.transform!) == 0.0) {
        return null;
      }
      position = MatrixUtils.transformPoint(inverse, position);
    }
    if (!node.rect.contains(position)) {
      return null;
    }

    final data = node.getSemanticsData();
    if ((data.actions & SemanticsAction.tap.index) > 0) {
      return data;
    }

    SemanticsData? result;
    node.visitChildren((SemanticsNode child) {
      final SemanticsData? currentData =
          _getSemanticsDataAtPosition(child, position);
      if (currentData != null) {
        result = currentData;
        return false;
      }
      return true;
    });
    return result;
  }
}
