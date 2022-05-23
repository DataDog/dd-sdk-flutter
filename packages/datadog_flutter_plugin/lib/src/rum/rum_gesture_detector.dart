// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import 'ddrum.dart';

class RumGestureDetector extends StatefulWidget {
  @internal
  static final elementMap = <RumGestureDetector, Element>{};

  final DdRum? rum;
  final Widget child;

  const RumGestureDetector({Key? key, required this.rum, required this.child})
      : super(key: key);

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
  //late PipelineOwner _pipelineOwner;

  @override
  void initState() {
    super.initState();
    //_pipelineOwner = WidgetsBinding.instance.pipelineOwner;
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
  }

  @override
  void dispose() {
    super.dispose();
    RumGestureDetector.elementMap.remove(widget);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: _listenerKey,
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: widget.child,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    var detectingElement = _getDetectingElementAtPosition(event.localPosition);
    if (detectingElement != null) {
      final description = _findElementDescription(detectingElement);

      print('Tapped "$description"');
    }

    // var rootSemantics = _pipelineOwner.semanticsOwner?.rootSemanticsNode;
    // if (rootSemantics != null) {
    //   final position =
    //       event.localPosition * WidgetsBinding.instance.window.devicePixelRatio;

    //   var data = _getSemanticsDataAtPosition(rootSemantics, position);
    //   print(data?.label);
    // }

    // RenderBox? box =
    //     _listenerKey.currentContext?.findRenderObject() as RenderBox?;

    // if (box != null) {
    //   var result = BoxHitTestResult();

    //   box.hitTest(result, position: event.localPosition);

    //   for (final hitTestEntry in result.path) {
    //     final target = hitTestEntry.target;
    //     if (target is RenderSemanticsAnnotations) {
    //       if (target.button ?? false) {
    //         print('Found a button: $target - ${target.attributedLabel}');
    //       }
    //     }
    //   }

    //   //widget.rum?.addUserAction(RumUserActionType.tap, 'test');
    // }
  }

  String _findElementDescription(Element element) {
    var elementDescription = '(unknown)';

    void visitor(Element element) {
      var widget = element.widget;
      if (widget is Text) {
        elementDescription = widget.data ?? '(unknown)';
      } else if (widget is Icon) {
        elementDescription = widget.semanticLabel ?? widget.icon.toString();
      } else {
        element.visitChildren(visitor);
      }
    }

    element.visitChildren(visitor);

    return elementDescription;
  }

  Element? _getDetectingElementAtPosition(Offset position) {
    var rootElement = RumGestureDetector.elementMap[widget];
    if (rootElement == null) return null;

    Element? candidateElement;

    void elementVisitor(Element element) {
      final ro = element.renderObject;
      if (ro == null) return;

      final transform = ro.getTransformTo(rootElement.renderObject);
      final paintBounds = MatrixUtils.transformRect(transform, ro.paintBounds);

      if (paintBounds.contains(position)) {
        final widget = element.widget;
        if (_widgetIsEnabledButtonType(widget)) {
          candidateElement = element;
        } else {
          element.visitChildElements(elementVisitor);
        }
      }
    }

    rootElement.visitChildElements(elementVisitor);

    return candidateElement;
  }

  bool _widgetIsEnabledButtonType(Widget widget) {
    if (widget is ButtonStyleButton) {
      return widget.enabled;
    } else if (widget is MaterialButton) {
      return widget.enabled;
    } else if (widget is CupertinoButton) {
      return widget.enabled;
    } else if (widget is InkWell) {
      return widget.onTap != null;
    } else if (widget is IconButton) {
      return widget.onPressed != null;
    }

    return false;
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
