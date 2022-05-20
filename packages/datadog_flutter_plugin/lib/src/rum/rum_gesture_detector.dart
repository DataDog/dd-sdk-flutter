// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'ddrum.dart';

class RumGestureDetector extends StatefulWidget {
  final DdRum? rum;
  final Widget child;

  const RumGestureDetector({Key? key, required this.rum, required this.child})
      : super(key: key);

  @override
  State<RumGestureDetector> createState() => _RumGestureDetectorState();
}

class _RumGestureDetectorState extends State<RumGestureDetector> {
  final _listenerKey = GlobalKey();
  late PipelineOwner _pipelineOwner;

  @override
  void initState() {
    super.initState();
    _pipelineOwner = WidgetsBinding.instance.pipelineOwner;
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
    var rootSemantics = _pipelineOwner.semanticsOwner?.rootSemanticsNode;
    if (rootSemantics != null) {
      final position =
          event.localPosition * WidgetsBinding.instance.window.devicePixelRatio;
      var data = _getSemanticsDataAtPosition(rootSemantics, position);
      print(data?.label);
    }

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
