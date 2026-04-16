// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../../../datadog_session_replay.dart';
import '../../extensions.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../text_masking.dart';
import '../view_tree_snapshot.dart';
import 'common_nodes.dart';
import 'recording_extensions.dart';

// ---------------------------------------------------------------------------
// _SpanSegment — a contiguous text run with its resolved (effective) style
// and character-offset range within the full InlineSpan plain-text string.
// ---------------------------------------------------------------------------

class _SpanSegment {
  final String text;
  final TextStyle effectiveStyle;

  /// Inclusive start character offset within the full InlineSpan string.
  final int startOffset;

  /// Exclusive end character offset.
  final int endOffset;

  const _SpanSegment({
    required this.text,
    required this.effectiveStyle,
    required this.startOffset,
    required this.endOffset,
  });
}

// ---------------------------------------------------------------------------
// TextElementRecorder
// ---------------------------------------------------------------------------

class TextElementRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const TextElementRecorder(this.keyGenerator);

  @override
  List<Type> get handlesTypes => [RichText];

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! RichText) return null;

    final textSpan = widget.text;
    if (textSpan is! TextSpan) return null;

    final privacy = capturePrivacy.textAndInputPrivacyLevel;
    final alignment = widget.textAlign.getSrHorizontalAlignment(
      widget.textDirection,
    );

    final segments = _collectSegments(textSpan, const TextStyle(), privacy);
    final hasWidgetChildren = _containsWidgetSpan(textSpan);

    // Fast path: single segment or all segments share the same effective style.
    // Produce a single wireframe for the whole widget (existing behaviour).
    if (segments.length <= 1 || !_hasDistinctStyles(segments)) {
      final buffer = StringBuffer();
      for (final seg in segments) {
        buffer.write(seg.text);
      }
      final rootStyle = textSpan.style;
      return SpecificElement(
        subtreeStrategy: hasWidgetChildren
            ? CaptureNodeSubtreeStrategy.record
            : CaptureNodeSubtreeStrategy.ignore,
        nodes: [
          TextElementCaptureNode(
            attributes,
            wireframeId: keyGenerator.keyForElement(element),
            text: buffer.toString(),
            color: rootStyle?.color?.toHexString() ?? Colors.black.toHexString(),
            family: rootStyle?.fontFamily ?? '',
            size: ((rootStyle?.fontSize?.toInt() ?? 10) * attributes.scaleX)
                .toInt(),
            alignment: alignment,
          ),
        ],
      );
    }

    // Multi-style path: one wireframe per span bounding box.
    // Use RenderParagraph.getBoxesForSelection to obtain the pixel bounds of
    // each span's character range, then produce a TextElementCaptureNode per box.
    final renderParagraph = element.renderObject;
    if (renderParagraph is! RenderParagraph) {
      return _singleWireframeFallback(
        textSpan, segments, attributes, alignment, element,
      );
    }

    final nodes = <CaptureNode>[];
    int subIndex = 0;

    for (final seg in segments) {
      if (seg.text.isEmpty) continue;

      final boxes = renderParagraph.getBoxesForSelection(
        TextSelection(
          baseOffset: seg.startOffset,
          extentOffset: seg.endOffset,
        ),
      );

      for (final box in boxes) {
        // Convert local RenderParagraph coordinates to the top-element
        // coordinate space using the scale factors already computed by the
        // recorder (valid for non-rotated layouts which cover 99 %+ of UI).
        final boxGlobal = Rect.fromLTRB(
          box.left * attributes.scaleX + attributes.paintBounds.left,
          box.top * attributes.scaleY + attributes.paintBounds.top,
          box.right * attributes.scaleX + attributes.paintBounds.left,
          box.bottom * attributes.scaleY + attributes.paintBounds.top,
        );

        // The first node reuses the element's primary key for stable diffing.
        final wireframeId = subIndex == 0
            ? keyGenerator.keyForElement(element)
            : keyGenerator.subKeyForElement(element, subIndex - 1);
        subIndex++;

        final style = seg.effectiveStyle;
        nodes.add(
          TextElementCaptureNode(
            CapturedViewAttributes(
              paintBounds: boxGlobal,
              scaleX: attributes.scaleX,
              scaleY: attributes.scaleY,
            ),
            wireframeId: wireframeId,
            text: seg.text,
            color: style.color?.toHexString() ?? Colors.black.toHexString(),
            family: style.fontFamily ?? '',
            size: ((style.fontSize?.toInt() ?? 10) * attributes.scaleX).toInt(),
            alignment: alignment,
          ),
        );
      }
    }

    if (nodes.isEmpty) {
      return _singleWireframeFallback(
        textSpan, segments, attributes, alignment, element,
      );
    }

    return SpecificElement(
      subtreeStrategy: hasWidgetChildren
          ? CaptureNodeSubtreeStrategy.record
          : CaptureNodeSubtreeStrategy.ignore,
      nodes: nodes,
    );
  }

  // ---------------------------------------------------------------------------
  // Fallback: single wireframe with concatenated text (old behaviour).
  // Used when getBoxesForSelection returns empty or the render object is not
  // a RenderParagraph.
  // ---------------------------------------------------------------------------

  CaptureNodeSemantics _singleWireframeFallback(
    TextSpan textSpan,
    List<_SpanSegment> segments,
    CapturedViewAttributes attributes,
    SRHorizontalAlignment alignment,
    Element element,
  ) {
    final buffer = StringBuffer();
    for (final seg in segments) {
      buffer.write(seg.text);
    }
    final rootStyle = textSpan.style;
    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: [
        TextElementCaptureNode(
          attributes,
          wireframeId: keyGenerator.keyForElement(element),
          text: buffer.toString(),
          color: rootStyle?.color?.toHexString() ?? Colors.black.toHexString(),
          family: rootStyle?.fontFamily ?? '',
          size: ((rootStyle?.fontSize?.toInt() ?? 10) * attributes.scaleX)
              .toInt(),
          alignment: alignment,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Span tree walking
  // ---------------------------------------------------------------------------

  /// Collects leaf text segments from [span], resolving the effective style at
  /// each node by merging parent styles downward (child style overrides parent).
  ///
  /// [offset] tracks the running character index into the full plain-text
  /// representation so that offsets align with
  /// [RenderParagraph.getBoxesForSelection].  Each [WidgetSpan] occupies one
  /// character (U+FFFC, the Unicode OBJECT REPLACEMENT CHARACTER) in that
  /// representation but is not captured here.
  List<_SpanSegment> _collectSegments(
    TextSpan span,
    TextStyle inheritedStyle,
    TextAndInputPrivacyLevel privacy,
  ) {
    final result = <_SpanSegment>[];
    int offset = 0;

    void visit(TextSpan s, TextStyle parentStyle) {
      // The effective style is the parent's style merged with the child's.
      // In Flutter, merging A into B means B's non-null properties win.
      final effective = parentStyle.merge(s.style);

      if (s.text case final text? when text.isNotEmpty) {
        final displayText = privacy == TextAndInputPrivacyLevel.maskAll
            ? maskTextPreservingSpaces(text)
            : text;
        result.add(
          _SpanSegment(
            text: displayText,
            effectiveStyle: effective,
            startOffset: offset,
            endOffset: offset + text.length,
          ),
        );
        offset += text.length;
      }

      s.children?.forEach((child) {
        if (child is TextSpan) {
          visit(child, effective);
        } else if (child is WidgetSpan) {
          // Advance offset to account for the U+FFFC placeholder character.
          offset += 1;
        }
      });
    }

    visit(span, inheritedStyle);
    return result;
  }

  /// Returns `true` when at least two segments differ in a visually meaningful
  /// style property (color, font size, or font family).
  bool _hasDistinctStyles(List<_SpanSegment> segments) {
    if (segments.length < 2) return false;
    final first = segments.first.effectiveStyle;
    for (int i = 1; i < segments.length; i++) {
      final s = segments[i].effectiveStyle;
      if (s.color != first.color ||
          s.fontSize != first.fontSize ||
          s.fontFamily != first.fontFamily) {
        return true;
      }
    }
    return false;
  }

  /// Returns `true` if the span tree contains at least one [WidgetSpan].
  bool _containsWidgetSpan(TextSpan span) {
    final children = span.children;
    if (children == null) return false;
    for (final child in children) {
      if (child is WidgetSpan) return true;
      if (child is TextSpan && _containsWidgetSpan(child)) return true;
    }
    return false;
  }
}
