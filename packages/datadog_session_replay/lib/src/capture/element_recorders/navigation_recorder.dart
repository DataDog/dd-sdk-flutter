// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../../extensions.dart';
import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../view_tree_snapshot.dart';
import 'common_nodes.dart';

// ---------------------------------------------------------------------------
// Default colours
// ---------------------------------------------------------------------------

const _kDefaultIndicatorColor = Color(0xFF6200EE); // Material purple
const _kDefaultBackgroundColor = Color(0xFFFFFFFF);
const _kM3IndicatorColor = Color(0xFFE8DEF8); // Material 3 secondary container
const _kRailIndicatorColor = Color(0xFFE8DEF8);

// Thickness of the TabBar underline indicator in logical pixels.
const _kTabIndicatorHeight = 3.0;

// Height of the NavigationBar pill indicator as a fraction of the bar height.
const _kNavBarIndicatorHeightRatio = 0.60;

// Width of the NavigationRail indicator relative to the rail width.
const _kRailIndicatorWidthRatio = 0.85;
// Height of the NavigationRail pill indicator in logical pixels.
const _kRailIndicatorHeight = 32.0;

// ---------------------------------------------------------------------------
// NavigationRecorder
// ---------------------------------------------------------------------------

/// Records navigation widgets and overlays a selection-indicator wireframe to
/// make the currently selected item visible in Session Replay.
///
/// Strategy: [AmbiguousElement] with [CaptureNodeSubtreeStrategy.record] so
/// that child text / icon widgets are captured by their own recorders while
/// this recorder contributes only the indicator shape.
///
/// Supported widgets:
///   • [TabBar]              — horizontal tab bar with underline indicator
///   • [BottomNavigationBar] — Material 2 bottom nav with highlight indicator
///   • [NavigationBar]       — Material 3 bottom nav with pill indicator
///   • [NavigationRail]      — vertical side nav with pill indicator
class NavigationRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const NavigationRecorder(this.keyGenerator);

  @override
  List<Type> get handlesTypes => [
        TabBar,
        BottomNavigationBar,
        NavigationBar,
        NavigationRail,
      ];

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is TabBar) return _captureTabBar(widget, element, attributes);
    if (widget is BottomNavigationBar) {
      return _captureBottomNavigationBar(widget, element, attributes);
    }
    if (widget is NavigationBar) {
      return _captureNavigationBar(widget, element, attributes);
    }
    if (widget is NavigationRail) {
      return _captureNavigationRail(widget, element, attributes);
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // TabBar
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _captureTabBar(
    TabBar widget,
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final indicatorKey = keyGenerator.keyForElement(element);

    // Resolve the active tab controller (widget-level or inherited).
    final TabController? controller =
        widget.controller ?? DefaultTabController.maybeOf(element);
    final int selectedIndex = controller?.index ?? 0;
    final int tabCount =
        widget.tabs.isNotEmpty ? widget.tabs.length : (controller?.length ?? 0);

    final nodes = <CaptureNode>[];

    if (tabCount > 0) {
      final bounds = attributes.paintBounds;
      final tabWidth = bounds.width / tabCount;
      final indicatorColor =
          widget.indicatorColor ?? widget.labelColor ?? _kDefaultIndicatorColor;

      final indicatorLeft = bounds.left + tabWidth * selectedIndex;
      final indicatorBounds = Rect.fromLTWH(
        indicatorLeft,
        bounds.bottom - _kTabIndicatorHeight,
        tabWidth,
        _kTabIndicatorHeight,
      );

      nodes.add(
        ContainerNode(
          CapturedViewAttributes(
            paintBounds: indicatorBounds,
            scaleX: attributes.scaleX,
            scaleY: attributes.scaleY,
          ),
          wireframeId: indicatorKey,
          style: ContainerStyle(
            backgroundColor: indicatorColor.toHexString(),
            cornerRadius: _kTabIndicatorHeight / 2,
          ),
        ),
      );
    }

    // AmbiguousElement: record children (tab labels handled by text recorder).
    return AmbiguousElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.record,
      nodes: nodes,
    );
  }

  // -------------------------------------------------------------------------
  // BottomNavigationBar (Material 2)
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _captureBottomNavigationBar(
    BottomNavigationBar widget,
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final bgKey = keyGenerator.keyForElement(element);
    final indicatorKey = keyGenerator.subKeyForElement(element, 0);

    final bounds = attributes.paintBounds;
    final itemCount = widget.items.length;
    final bgColor =
        widget.backgroundColor ?? _kDefaultBackgroundColor;
    final indicatorColor =
        widget.selectedItemColor ?? _kDefaultIndicatorColor;

    final nodes = <CaptureNode>[
      // Background container.
      ContainerNode(
        attributes,
        wireframeId: bgKey,
        style: ContainerStyle(backgroundColor: bgColor.toHexString()),
      ),
    ];

    if (itemCount > 0) {
      // Highlight: a rounded rectangle centred over the selected item.
      final itemWidth = bounds.width / itemCount;
      final highlightWidth = itemWidth * 0.6;
      final highlightHeight = bounds.height * 0.55;
      final highlightLeft =
          bounds.left + itemWidth * widget.currentIndex + (itemWidth - highlightWidth) / 2;
      final highlightTop =
          bounds.top + (bounds.height - highlightHeight) / 2;

      nodes.add(
        ContainerNode(
          CapturedViewAttributes(
            paintBounds: Rect.fromLTWH(
              highlightLeft,
              highlightTop,
              highlightWidth,
              highlightHeight,
            ),
            scaleX: attributes.scaleX,
            scaleY: attributes.scaleY,
          ),
          wireframeId: indicatorKey,
          style: ContainerStyle(
            backgroundColor: indicatorColor.withOpacity(0.12).toHexString(),
            cornerRadius: highlightHeight / 2,
          ),
        ),
      );
    }

    return AmbiguousElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.record,
      nodes: nodes,
    );
  }

  // -------------------------------------------------------------------------
  // NavigationBar (Material 3)
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _captureNavigationBar(
    NavigationBar widget,
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final bgKey = keyGenerator.keyForElement(element);
    final indicatorKey = keyGenerator.subKeyForElement(element, 0);

    final bounds = attributes.paintBounds;
    final destCount = widget.destinations.length;
    final bgColor = widget.backgroundColor ?? _kDefaultBackgroundColor;
    final indicatorColor =
        widget.indicatorColor ?? _kM3IndicatorColor;

    final nodes = <CaptureNode>[
      ContainerNode(
        attributes,
        wireframeId: bgKey,
        style: ContainerStyle(backgroundColor: bgColor.toHexString()),
      ),
    ];

    if (destCount > 0) {
      // Pill indicator centred over the selected destination.
      final itemWidth = bounds.width / destCount;
      final pillWidth = itemWidth * 0.70;
      final pillHeight = bounds.height * _kNavBarIndicatorHeightRatio;
      final pillLeft = bounds.left +
          itemWidth * widget.selectedIndex +
          (itemWidth - pillWidth) / 2;
      final pillTop = bounds.top + (bounds.height - pillHeight) / 2;

      nodes.add(
        ContainerNode(
          CapturedViewAttributes(
            paintBounds: Rect.fromLTWH(
              pillLeft,
              pillTop,
              pillWidth,
              pillHeight,
            ),
            scaleX: attributes.scaleX,
            scaleY: attributes.scaleY,
          ),
          wireframeId: indicatorKey,
          style: ContainerStyle(
            backgroundColor: indicatorColor.toHexString(),
            cornerRadius: pillHeight / 2,
          ),
        ),
      );
    }

    return AmbiguousElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.record,
      nodes: nodes,
    );
  }

  // -------------------------------------------------------------------------
  // NavigationRail
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _captureNavigationRail(
    NavigationRail widget,
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final bgKey = keyGenerator.keyForElement(element);
    final indicatorKey = keyGenerator.subKeyForElement(element, 0);

    final bounds = attributes.paintBounds;
    final destCount = widget.destinations.length;
    final bgColor = widget.backgroundColor ?? _kDefaultBackgroundColor;
    final indicatorColor = widget.indicatorColor ?? _kRailIndicatorColor;

    final nodes = <CaptureNode>[
      ContainerNode(
        attributes,
        wireframeId: bgKey,
        style: ContainerStyle(backgroundColor: bgColor.toHexString()),
      ),
    ];

    // NavigationRail lays destinations vertically.
    // The leading widget (e.g. fab) sits above the destinations, so we
    // approximate the destination item height from the total bounds.
    if (destCount > 0) {
      final itemHeight = bounds.height / destCount;
      final pillWidth = bounds.width * _kRailIndicatorWidthRatio;
      final pillHeight = _kRailIndicatorHeight;
      final pillLeft = bounds.left + (bounds.width - pillWidth) / 2;
      final pillTop = bounds.top +
          itemHeight * widget.selectedIndex +
          (itemHeight - pillHeight) / 2;

      nodes.add(
        ContainerNode(
          CapturedViewAttributes(
            paintBounds: Rect.fromLTWH(
              pillLeft,
              pillTop,
              pillWidth,
              pillHeight,
            ),
            scaleX: attributes.scaleX,
            scaleY: attributes.scaleY,
          ),
          wireframeId: indicatorKey,
          style: ContainerStyle(
            backgroundColor: indicatorColor.toHexString(),
            cornerRadius: pillHeight / 2,
          ),
        ),
      );
    }

    return AmbiguousElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.record,
      nodes: nodes,
    );
  }
}
