// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../../extensions.dart';
import '../../sr_data_models.dart';
import '../capture_node.dart';

@immutable
class CapturedBorderStyle {
  final double? cornerRadius;
  final double? width;
  final String? color;

  const CapturedBorderStyle({
    required this.cornerRadius,
    required this.width,
    required this.color,
  });

  static CapturedBorderStyle? fromShapeBorder(
    ShapeBorder? shape,
    CapturedViewAttributes attributes,
  ) {
    switch (shape) {
      case final StadiumBorder _:
        final shortSide = attributes.paintBounds.shortestSide;
        return CapturedBorderStyle(
          cornerRadius: shortSide / 2,
          width: shape.side.width,
          color: shape.side.color.toHexString(),
        );
      case final CircleBorder _:
        final shortSide = attributes.paintBounds.shortestSide;
        return CapturedBorderStyle(
          cornerRadius: shortSide / 2,
          width: shape.side.width,
          color: shape.side.color.toHexString(),
        );
      case final RoundedRectangleBorder shape:
        // Text direction only matters for border radius if we support
        // per-side borders and per-corner border radius.
        return CapturedBorderStyle(
          cornerRadius: shape.borderRadius.resolve(null).topLeft.x,
          width: shape.side.width,
          color: shape.side.color.toHexString(),
        );
      case final RoundedSuperellipseBorder shape:
        // CupertinoButton uses RoundedSuperellipseBorder (iOS squircle).
        // Approximated as a rounded rectangle since SRShapeStyle only
        // carries a single cornerRadius scalar.
        return CapturedBorderStyle(
          cornerRadius: shape.borderRadius.resolve(null).topLeft.x,
          width: shape.side.width,
          color: shape.side.color.toHexString(),
        );
      case final UnderlineInputBorder shape:
        // TODO: Allow per-side borders
        return CapturedBorderStyle(
          cornerRadius: shape.borderRadius.resolve(null).topLeft.x,
          width: shape.borderSide.width,
          color: shape.borderSide.color.toHexString(),
        );
      case final OutlineInputBorder shape:
        // Text direction only matters for border radius if we support
        // per-side borders and per-corner border radius.
        return CapturedBorderStyle(
          cornerRadius: shape.borderRadius.resolve(null).topLeft.x,
          width: shape.borderSide.width,
          color: shape.borderSide.color.toHexString(),
        );
    }
    return null;
  }
}

@immutable
class ContainerStyle {
  final String? backgroundColor;
  final String? borderColor;
  final double? borderWidth;
  final double cornerRadius;

  const ContainerStyle({
    required this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.cornerRadius = 0.0,
  });

  static ContainerStyle? fromDecoration(
    Decoration decoration,
    CapturedViewAttributes attributes,
  ) {
    switch (decoration) {
      case BoxDecoration boxDecoration:
        return _captureBoxDecoration(boxDecoration, attributes);
      case ShapeDecoration shapeDecoration:
        return _captureShapeDecoration(shapeDecoration, attributes);
    }
    return null;
  }

  static ContainerStyle? fromInputDecoration(
    InputDecoration decoration,
    bool isFocused,
    CapturedViewAttributes attributes,
  ) {
    bool hasError = decoration.errorText != null || decoration.error != null;
    InputBorder? border;
    if (!decoration.enabled) {
      border = hasError ? decoration.errorBorder : decoration.disabledBorder;
    } else if (isFocused) {
      border =
          hasError ? decoration.focusedErrorBorder : decoration.focusedBorder;
    } else {
      border = hasError ? decoration.errorBorder : decoration.enabledBorder;
    }
    border ??= decoration.border;
    border ??= _getDefaultInputBorder();

    final capturedBorder = CapturedBorderStyle.fromShapeBorder(
      border,
      attributes,
    );
    return ContainerStyle(
      backgroundColor: decoration.fillColor?.toHexString(),
      borderColor: capturedBorder?.color,
      cornerRadius: capturedBorder?.cornerRadius ?? 0,
      borderWidth: capturedBorder?.width,
    );
  }
}

InputBorder _getDefaultInputBorder() {
  // TODO: Query material state. See input_border.dart:2181
  return const UnderlineInputBorder();
}

ContainerStyle _captureBoxDecoration(
    BoxDecoration decoration, CapturedViewAttributes attributes) {
  double? cornerRadius = decoration.borderRadius?.resolve(null).topLeft.x;
  if (decoration.shape == BoxShape.circle) {
    // Show this as a circle even if it has border radius
    final shortSide = attributes.paintBounds.shortestSide;
    cornerRadius = shortSide / 2;
  }
  Color? backgroundColor = decoration.color;
  double? borderWidth;
  Color? borderColor;
  if (decoration.border case final border?) {
    // TODO: Look into non-uniform borders for SR
    if (border.top.width > 0) {
      borderWidth = border.top.width;
      borderColor = border.top.color;
    } else if (border.bottom.width > 0) {
      borderWidth = border.bottom.width;
      borderColor = border.bottom.color;
    }
  }

  return ContainerStyle(
    backgroundColor: backgroundColor?.toHexString(),
    borderColor: borderColor?.toHexString(),
    borderWidth: borderWidth,
    cornerRadius: cornerRadius ?? 0.0,
  );
}

ContainerStyle _captureShapeDecoration(
  ShapeDecoration decoration,
  CapturedViewAttributes attributes,
) {
  final borderStyle = CapturedBorderStyle.fromShapeBorder(
    decoration.shape,
    attributes,
  );
  return ContainerStyle(
    backgroundColor: decoration.color?.toHexString(),
    borderColor: borderStyle?.color,
    borderWidth: borderStyle?.width,
    cornerRadius: borderStyle?.cornerRadius ?? 0.0,
  );
}

@immutable
class ContainerNode extends CaptureNode {
  final int wireframeId;
  final ContainerStyle style;

  const ContainerNode(
    super.attributes, {
    required this.wireframeId,
    required this.style,
  });

  @override
  List<SRWireframe> buildWireframes() {
    final attrs = attributes;
    SRShapeStyle? shapeStyle;
    SRShapeBorder? shapeBorder;
    if (style.backgroundColor != null || style.borderWidth != null) {
      shapeStyle = SRShapeStyle(
        backgroundColor: style.backgroundColor ?? srTransparentColorString,
        cornerRadius: style.cornerRadius,
      );

      if (style.borderWidth != null) {
        shapeBorder = SRShapeBorder(
          color: style.borderColor!,
          width: style.borderWidth!.safeRound(),
        );
      }
    }
    return [
      SRShapeWireframe(
        id: wireframeId,
        x: attrs.x,
        y: attrs.y,
        width: attrs.width,
        height: attrs.height,
        shapeStyle: shapeStyle,
        border: shapeBorder,
      ),
    ];
  }
}

@immutable
class TextElementCaptureNode extends CaptureNode {
  final int wireframeId;
  final String text;
  final String color;
  final String family;
  final int size;
  final SRHorizontalAlignment alignment;

  const TextElementCaptureNode(
    super.attributes, {
    required this.wireframeId,
    required this.text,
    required this.color,
    required this.family,
    required this.size,
    required this.alignment,
  });

  @override
  List<SRWireframe> buildWireframes() {
    return [
      SRTextWireframe(
        id: wireframeId,
        x: attributes.x,
        y: attributes.y,
        width: attributes.width,
        height: attributes.height,
        text: text,
        textStyle: SRTextStyle(color: color, family: family, size: size),
        textPosition: SRTextPosition(
          alignment: SRAlignment(horizontal: alignment),
        ),
      ),
    ];
  }
}
