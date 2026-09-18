// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ui' as ui;

import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/material.dart';

import 'mock_platform.dart';

/// Takes a Session Replay record and renders it to a canvas.
extension WireframeRendering on SRWireframe {
  Rect toRect() {
    return Rect.fromLTWH(
      x.toDouble(),
      y.toDouble(),
      width.toDouble(),
      height.toDouble(),
    );
  }

  void render(Canvas canvas) {
    switch (this) {
      case SRShapeWireframe shape:
        shape.render(canvas);
        break;
      case SRTextWireframe text:
        text.render(canvas);
        break;
      case SRPlaceholderWireframe placeholder:
        placeholder.render(canvas);
        break;
      case SRImageWireframe image:
        image.render(canvas);
        break;
      default:
        throw UnsupportedError('Error rendering wireframe: $runtimeType');
    }
  }
}

void _renderShape(
  Canvas canvas,
  Rect rect,
  SRShapeBorder? border,
  SRShapeStyle? shapeStyle,
) {
  final cornerRadius = shapeStyle != null
      ? Radius.circular(shapeStyle.cornerRadius)
      : Radius.zero;
  if (border case final border?) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = border.width.toDouble()
      ..color = _colorFromHexString(border.color);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, cornerRadius), paint);
  }

  if (shapeStyle case final style?) {
    if (style.backgroundColor != srTransparentColorString) {
      final color = _colorFromHexString(style.backgroundColor);
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = color;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, cornerRadius), paint);
    }
  }
}

extension ShapeWireframeRendering on SRShapeWireframe {
  void render(Canvas canvas) {
    canvas.save();
    if (clip case final clip?) {
      canvas.clipRect(
        Rect.fromLTRB(
          clip.left.toDouble(),
          clip.top.toDouble(),
          clip.right.toDouble(),
          clip.bottom.toDouble(),
        ),
      );
    }

    _renderShape(canvas, toRect(), border, shapeStyle);

    canvas.restore();
  }
}

extension TextWireframeRendering on SRTextWireframe {
  void render(Canvas canvas) {
    canvas.save();
    if (clip case final clip?) {
      canvas.clipRect(
        Rect.fromLTRB(
          clip.left.toDouble(),
          clip.top.toDouble(),
          clip.right.toDouble(),
          clip.bottom.toDouble(),
        ),
      );
    }

    _renderShape(canvas, toRect(), border, shapeStyle);

    // Note if you're looking at the Goldens and seeing only boxes: golden
    // tests in Flutter do this on purpose to produce consistent results on all
    // platforms. See https://github.com/flutter/flutter/issues/28729
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: textPosition?.alignment?.toTextAlign(),
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: _colorFromHexString(textStyle.color),
          fontFamily: textStyle.family.split(',')[0],
          fontSize: textStyle.size.toDouble(),
        ),
      )
      ..addText(text);
    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: width.toDouble()));
    canvas.drawParagraph(paragraph, Offset(x.toDouble(), y.toDouble()));

    canvas.restore();
  }
}

extension PlaceholderWireframeRendering on SRPlaceholderWireframe {
  void render(Canvas canvas) {
    canvas.save();
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.grey;
    canvas.drawRect(toRect(), paint);

    if (label case final label?) {
      final paragraphBuilder =
          ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
            ..pushStyle(ui.TextStyle(color: Colors.black))
            ..addText(label);
      final paragraph = paragraphBuilder.build()
        ..layout(ui.ParagraphConstraints(width: width.toDouble()));
      // Approximate center height
      final renderY = y + (height / 2.0);
      canvas.drawParagraph(paragraph, Offset(x.toDouble(), renderY));
    }

    canvas.restore();
  }
}

extension ImageWireframeRendering on SRImageWireframe {
  void render(Canvas canvas) {
    final mockPlatform = DatadogSessionReplayPlatform.instance
        as MockDatadogSessionReplayPlatform;
    final imageData = mockPlatform.imageCache[resourceId!];
    if (imageData != null && imageData.image != null) {
      canvas.save();
      Rect srcRect = Rect.fromLTWH(
        0,
        0,
        imageData.width.toDouble(),
        imageData.height.toDouble(),
      );
      canvas.drawImageRect(imageData.image!, srcRect, toRect(), Paint());
      canvas.restore();
    }
  }
}

extension TextAlignHelper on SRAlignment {
  TextAlign toTextAlign() {
    switch (horizontal) {
      case null:
      case SRHorizontalAlignment.left:
        return TextAlign.left;
      case SRHorizontalAlignment.center:
        return TextAlign.center;
      case SRHorizontalAlignment.right:
        return TextAlign.right;
    }
  }
}

Color _colorFromHexString(String hex) {
  if (hex.startsWith('#')) {
    hex = hex.substring(1);
  }
  final intValue = int.parse(hex, radix: 16);
  return Color.fromARGB(
    intValue & 0xFF,
    intValue >> 24 & 0xFF,
    intValue >> 16 & 0xFF,
    intValue >> 8 & 0xFF,
  );
}

class WireframeCustomPainter extends CustomPainter {
  final List<SRWireframe> wireframes;

  WireframeCustomPainter(this.wireframes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final wireframe in wireframes) {
      wireframe.render(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
