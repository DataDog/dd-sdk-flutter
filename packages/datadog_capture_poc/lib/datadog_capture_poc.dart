// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:ui' as ui show Image;

import 'package:collection/collection.dart';
import 'package:datadog_capture_poc/src/capture_uploader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'src/models/wireframe_payload.dart';

final _buttonTypes = [
  FlatButton,
  RaisedButton,
  ElevatedButton,
  TextButton,
  MaterialButton,
];

class DatadogCaptureManager {
  final CaptureUploader _uploader;

  //Map<Key, _DatadogCapturingRenderObject> renderObjects = {};
  Map<Key, Element> elements = {};

  Map<Element, String> capturedImages = <Element, String>{};

  DatadogCaptureManager(String serverUri)
      : _uploader = CaptureUploader(serverUri);

  Future<void> performCapture() async {
    // for (final item in renderObjects.values) {
    //   item.capture();
    // }

    for (final item in elements.values) {
      final stopwatch = Stopwatch();
      stopwatch.start();
      var widget = item.widget;
      ui.Image? uiImageCapture;
      if (widget is DatadogCapturingWidget) {
        var captureState =
            (item as StatefulElement).state as _DatadogCapturingWidgetState;
        var renderObject = captureState.repaintKey.currentContext
            ?.findRenderObject() as RenderRepaintBoundary?;
        if (renderObject != null) {
          while (renderObject.debugNeedsPaint) {
            await Future.delayed(const Duration(milliseconds: 10));
          }
          uiImageCapture = await renderObject.toImage();
        }
      }
      stopwatch.stop();
      print('Screen Capture Took: ${stopwatch.elapsed}');

      final payload = _captureElement(item, uiImageCapture);

      if (payload != null) {
        var wireframes = _flattenWireframe(payload);

        wireframes =
            wireframes.where((e) => e.kind != WireframeKind.utility).toList();

        await _uploader.uploadImages(wireframes);
        unawaited(_uploader.uploadWireframes(wireframes));
      }
    }
  }

  List<Wireframe> _flattenWireframe(Wireframe wireframe) {
    List<Wireframe> flattened = [];

    void traverse(Wireframe start, bool Function(Wireframe) visitor) {
      final shouldSkipChildren = visitor(start);
      if (shouldSkipChildren) return;

      for (final child in start.wireframeChildren) {
        traverse(child, visitor);
      }
    }

    traverse(wireframe, (child) {
      flattened.add(child);
      return false;
    });

    return flattened;
  }

  Wireframe? _captureElement(Element e, ui.Image? fullCapture) {
    Stopwatch stopwatch = Stopwatch();
    stopwatch.start();

    void visitor(Element element, Wireframe elementWireframe, int depth) {
      element.visitChildElements((child) {
        final ro = child.renderObject;
        if (ro == null) return;

        final mat = ro.getTransformTo(e.renderObject);
        final size = ro.paintBounds;
        final paintBounds = MatrixUtils.transformRect(mat, size);

        WireframeKind kind = WireframeKind.utility;
        WireframeTextOptions? textOptions;
        WireframeImageCapture? imageCapture;
        WireframeImageOptions? imageOptions;
        Color? backgroundColor;

        final widget = child.widget;
        if (widget is RichText) {
          final textSpan = widget.text;
          // TODO: Support other inline spans / child spans
          if (textSpan is TextSpan) {
            kind = WireframeKind.label;
            final style = textSpan.style;
            textOptions = WireframeTextOptions(
              text: textSpan.text,
              fontFamilyName: style?.fontFamily,
              fontSize: style?.fontSize,
              textColor: style?.color?.toHexString(),
            );
          }
        } else if (widget is Material) {
          kind = WireframeKind.unknown;
          backgroundColor = widget.color;
        } else if (widget is RawImage && widget.image != null) {
          kind = WireframeKind.image;
          if (!capturedImages.containsKey(child)) {
            imageCapture = WireframeImageCapture(
              id: uuid.v4(),
              capture: widget.image!,
            );
            capturedImages[child] = imageCapture.id;
            imageOptions = WireframeImageOptions(
              imageName: imageCapture.id,
            );
          } else {
            imageOptions = WireframeImageOptions(
              imageName: capturedImages[child],
            );
          }
        } else if (_buttonTypes
                .firstWhereOrNull((type) => type == widget.runtimeType) !=
            null) {
          kind = WireframeKind.button;
        } else if (widget is FlutterLogo && fullCapture != null) {
          kind = WireframeKind.image;
          imageCapture = WireframeImageCapture(
            id: uuid.v4(),
            capture: fullCapture,
            cropRect: true,
          );
          imageOptions = WireframeImageOptions(
            imageName: imageCapture.id,
          );
        }

        final childWireframe = Wireframe(
          x: paintBounds.left,
          y: paintBounds.top,
          w: paintBounds.width,
          h: paintBounds.height,
          kind: kind,
          backgroundColor: backgroundColor?.toHexString(),
          textOptions: textOptions,
          imageOptions: imageOptions,
          imageCapture: imageCapture,
        );
        visitor(child, childWireframe, depth + 1);

        elementWireframe.wireframeChildren.add(childWireframe);
      });
    }

    Wireframe? wireframe;
    final ro = e.renderObject;
    if (ro == null) return null;

    // The first captured element is 'unknown' for now to fill the area
    final mat = ro.getTransformTo(e.renderObject);
    final size = ro.paintBounds;
    final paintBounds = MatrixUtils.transformRect(mat, size);
    wireframe = Wireframe(
      x: paintBounds.left,
      y: paintBounds.top,
      w: paintBounds.width,
      h: paintBounds.height,
      kind: WireframeKind.unknown,
      backgroundColor: '#ffffffff',
    );
    e.visitChildElements((child) {
      final ro = child.renderObject;
      if (ro == null) return;

      visitor(child, wireframe!, 1);
    });

    stopwatch.stop();
    print("Capture completed in ${stopwatch.elapsed.toString()}");

    return wireframe;
  }
}

class DatadogCapturingWidget extends StatefulWidget {
  final Widget child;
  final DatadogCaptureManager manager;

  const DatadogCapturingWidget(
      {Key? key, required this.manager, required this.child})
      : super(key: key);

  @override
  StatefulElement createElement() {
    final e = super.createElement();
    if (key != null) {
      manager.elements[key!] = e;
    }
    return e;
  }

  @override
  State<DatadogCapturingWidget> createState() => _DatadogCapturingWidgetState();
}

class _DatadogCapturingWidgetState extends State<DatadogCapturingWidget> {
  final repaintKey = GlobalKey();

  @override
  void dispose() {
    widget.manager.elements.remove(widget.key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: widget.child,
    );
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

extension Hex on Color {
  String toHexString() {
    final sb = StringBuffer('#');
    for (final component in [red, green, blue, alpha]) {
      sb.write(component.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
