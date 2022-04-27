// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class DatadogCaptureManager {
  Map<Key, _DatadogCapturingRenderObject> renderObjects = {};
  Map<Key, Element> elements = {};

  void performCapture() {
    for (final item in renderObjects.values) {
      print(item.capture());
    }

    for (final item in elements.values) {
      _captureElement(item);
    }
  }

  void _captureElement(Element e) {
    final buffer = StringBuffer('[\n');
    Stopwatch stopwatch = Stopwatch();
    stopwatch.start();
    void visitor(Element child, int depth) {
      child.visitChildElements((nextChild) {
        buffer.write(' ' * depth);
        String paintBounds = '';
        final ro = nextChild.renderObject;
        if (ro != null) {
          final mat = ro.getTransformTo(e.renderObject);
          final size = ro.paintBounds;
          paintBounds = '(${MatrixUtils.transformRect(mat, size)})';
        }
        buffer.write('${child.toStringShort()}$paintBounds,\n');
        visitor(nextChild, depth + 1);
        print(buffer.toString());
        buffer.clear();
      });
    }

    e.visitChildElements((child) {
      visitor(child, 1);
    });

    stopwatch.stop();
    print("Capture completed in ${stopwatch.elapsed.toString()}");
  }
}

class DatadogCapturingWidget extends StatelessWidget {
  final Widget child;
  final DatadogCaptureManager manager;

  const DatadogCapturingWidget(
      {Key? key, required this.manager, required this.child})
      : super(key: key);

  @override
  StatelessElement createElement() {
    final e = super.createElement();
    if (key != null) {
      manager.elements[key!] = e;
    }
    return e;
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

// class DatadogCapturingWidget extends SingleChildRenderObjectWidget {
//   final DatadogCaptureManager manager;

//   const DatadogCapturingWidget({Key? key, required this.manager, Widget? child})
//       : super(key: key, child: child);

//   @override
//   RenderObject createRenderObject(BuildContext context) {
//     final ro = _DatadogCapturingRenderObject();
//     if (key != null) {
//       manager.renderObjects[key!] = ro;
//     }

//     return ro;
//   }

//   @override
//   void updateRenderObject(
//     BuildContext context,
//     covariant RenderObject renderObject,
//   ) {
//     if (renderObject is _DatadogCapturingRenderObject && key != null) {
//       manager.renderObjects[key!] = renderObject;
//     }
//   }

//   @override
//   void didUnmountRenderObject(covariant RenderObject renderObject) {
//     if (key != null) {
//       manager.renderObjects.remove(key!);
//     }
//   }
// }

class _DatadogCapturingRenderObject extends RenderProxyBox {
  String capture() {
    final buffer = StringBuffer('[\n');
    void visitor(RenderObject child, int depth) {
      child.visitChildrenForSemantics((nextChild) {
        buffer.write(' ' * depth);
        buffer.write('${child.toStringShort()},\n');
        visitor(nextChild, depth + 1);
      });
    }

    child?.visitChildrenForSemantics((child) {
      visitor(child, 1);
    });

    buffer.writeln(']');

    return buffer.toString();
  }
}
