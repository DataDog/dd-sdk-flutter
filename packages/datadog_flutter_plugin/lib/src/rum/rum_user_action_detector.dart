// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../../datadog_flutter_plugin.dart';
import '../../datadog_internal.dart';

// The distance a 'pointer' can move and still be considered a tap, in logical
// pixels.
const _tapSlop = 20;
const _tapSlopSquared = _tapSlop * _tapSlop;

@immutable
class _ElementDescription {
  final Element element;
  final String elementName;
  final String elementDescription;

  // Whether we can potentially do better than this element further down the
  // tree. Used for non-specific widgets like `GestureDetector` and `InkWell`
  // which are meant as a catch all but might have children (like `Tab`) that
  // are more descriptive.
  final bool tryForBetter;

  @override
  String toString() {
    return '$elementName($elementDescription)';
  }

  bool betterThan(_ElementDescription? other) {
    // Literally anything is better than GestureDetector
    if (element.widget is GestureDetector && other != null) {
      return false;
    }

    return true;
  }

  const _ElementDescription({
    required this.element,
    required this.elementName,
    required this.elementDescription,
    // ignore: unused_element
    this.tryForBetter = false,
  });
}

/// Detect simple user actions and send them to RUM.
///
/// This wrapper widget automatically detects tap user actions that occur in its
/// tree and sends them to RUM. It detects interactions with several common
/// Flutter widgets, including [ElevatedButton], [TextButton],
/// [CupertinoButton], [BottomNavigationBar], [TabBar], [InkWell], and
/// [GestureDetector].
///
/// For most Button types, the detector will look for a [Text] widget child,
/// which it will use for the description of the action. In other cases, it will
/// look for a child [Semantics] object, or an [Icon] with its [Icon.semanticsLabel]
/// property set.
///
/// Alternately, you can enclose any Widget tree with a
/// [RumUserActionAnnotation], which will use the provided description when
/// reporting user actions detected in the child tree, without changing the
/// Semantics of the tree.
class RumUserActionDetector extends StatefulWidget {
  @internal
  static final elementMap = <RumUserActionDetector, Element>{};

  /// The instance of RUM to report to.
  final DdRum? rum;

  /// The Widget tree to detect gestures in.
  final Widget child;

  const RumUserActionDetector({
    Key? key,
    required this.rum,
    required this.child,
  }) : super(key: key);

  @override
  StatefulElement createElement() {
    final e = super.createElement();
    elementMap[this] = e;
    return e;
  }

  @override
  State<RumUserActionDetector> createState() => _RumUserActionDetectorState();
}

class _RumUserActionDetectorState extends State<RumUserActionDetector> {
  static var _didUpdateTelemetry = false;

  final _listenerKey = GlobalKey();

  int? _lastPointerId;
  Offset? _lastPointerDownLocation;

  @override
  void initState() {
    super.initState();
    if (!_didUpdateTelemetry) {
      DatadogSdk.instance.updateConfigurationInfo(
          LateConfigurationProperty.trackInteractions, true);
      _didUpdateTelemetry = true;
    }
  }

  @override
  void didUpdateWidget(covariant RumUserActionDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    var element = RumUserActionDetector.elementMap[oldWidget];
    if (element != null) {
      RumUserActionDetector.elementMap.remove(oldWidget);
      RumUserActionDetector.elementMap[widget] = element;
    } else {
      final st = StackTrace.current;
      widget.rum?.logger.sendToDatadog(
        'Error locating old widget in element map during didUpdateWidget',
        st,
        null,
      );
    }
  }

  @override
  void dispose() {
    RumUserActionDetector.elementMap.remove(widget);
    super.dispose();
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
    final elementDescription = _getDetectingElementAtPosition(position);

    if (elementDescription != null) {
      widget.rum?.addUserAction(action, elementDescription.toString());
    }
  }

  String? _findElementInnerText(Element element, bool allowText) {
    String? elementDescription;

    void visitor(Element element) {
      bool stopVisits = false;

      var widget = element.widget;
      if (allowText && widget is Text) {
        if (widget.data?.isNotEmpty ?? false) {
          elementDescription = widget.data!;
          stopVisits = true;
        }
      } else if (widget is Semantics) {
        if (widget.properties.label?.isNotEmpty ?? false) {
          elementDescription = widget.properties.label!;
          stopVisits = true;
        }
      } else if (widget is Icon) {
        if (widget.semanticLabel?.isNotEmpty ?? false) {
          elementDescription = widget.semanticLabel!;
          stopVisits = true;
        }
      }

      if (!stopVisits) {
        element.visitChildren(visitor);
      }
    }

    element.visitChildren(visitor);

    return elementDescription;
  }

  _ElementDescription? _getDetectingElementAtPosition(Offset position) {
    var rootElement = RumUserActionDetector.elementMap[widget];
    if (rootElement == null) return null;

    final pointerListener = rootElement.renderObject;
    if (pointerListener == null || pointerListener is! RenderPointerListener) {
      return null;
    }

    var hitTestResult = BoxHitTestResult();
    pointerListener.hitTest(hitTestResult, position: position);
    var targets = hitTestResult.path.toList();

    _ElementDescription? detectingElement;

    String? rumTreeAnnotation;
    RenderObject? lastRenderObject;

    void elementVisitor(Element element) {
      // We already have a candidate element, or we hit something we don't detect
      if (detectingElement?.tryForBetter == false || targets.isEmpty) return;

      final ro = element.renderObject;
      if (ro == null) return;

      // Multiple elements in the tree can share render objects,
      // including our annotation object. Continue to check if the widgets
      // are detecting elements
      if (ro == targets.last.target) {
        targets.removeLast();
        lastRenderObject = ro;
      }

      if (ro == lastRenderObject) {
        final widget = element.widget;
        if (widget is RumUserActionAnnotation) {
          rumTreeAnnotation = widget.description;
        } else {
          final checkElement = _getDetectingElementDescription(
              element, targets, rumTreeAnnotation);
          if (checkElement != null &&
              checkElement.betterThan(detectingElement)) {
            detectingElement = checkElement;
          }
        }

        if (detectingElement?.tryForBetter != false) {
          element.visitChildElements(elementVisitor);
        }
        // This annotation was only for this tree
        rumTreeAnnotation = null;
      } else {
        // This element got skipped in the hit test, but if we're still
        // inside it's element tree, keep searching.
        // This is because large portions of the tree can get discarded
        // during the hit test process (especially around viewports)
        final transform = ro.getTransformTo(rootElement.renderObject);
        final paintBounds =
            MatrixUtils.transformRect(transform, ro.paintBounds);

        if (paintBounds.contains(position)) {
          element.visitChildElements(elementVisitor);
        }
      }
    }

    rootElement.visitChildElements(elementVisitor);

    return detectingElement;
  }

  _ElementDescription? _getDetectingElementDescription(
      Element element, List<HitTestEntry> targets, String? treeAnnotation) {
    final widget = element.widget;
    String? elementName;
    bool searchForBetter = false;
    bool searchForText = true;
    if (widget is ButtonStyleButton) {
      if (widget.enabled) {
        elementName = 'Button';
      }
    } else if (widget is MaterialButton) {
      if (widget.enabled) {
        elementName = 'Button';
      }
    } else if (widget is CupertinoButton) {
      if (widget.enabled) {
        elementName = 'Button';
      }
    } else if (widget is IconButton) {
      if (widget.onPressed != null) {
        elementName = 'IconButton';
        searchForText = false;
      }
    } else if (widget is Tab) {
      elementName = 'Tab';
    } else if (widget is BottomNavigationBar) {
      if (widget.onTap != null) {
        elementName = 'BottomNavigationBarItem';
        // Special case, if there's not already a tree annotation, get
        // the child gesture detector in the hit path and search through it for
        // a description.
        if (treeAnnotation == null) {
          final detectorElement = _findGestureDetectorElement(element, targets);
          if (detectorElement != null) {
            treeAnnotation = _findElementInnerText(detectorElement, true);
          }
        }
      }
    } else if (widget is Radio) {
      elementName = 'Radio';
      // If there's no tree annotation, use the value on the button
      treeAnnotation ??= widget.value?.toString();
    } else if (widget is Switch) {
      elementName = 'Switch';
    } else if (widget is InkWell) {
      if (widget.onTap != null) {
        elementName = 'InkWell';
        searchForBetter = true;
        searchForText = false;
      }
    } else if (widget is GestureDetector) {
      if (widget.onTap != null) {
        elementName = 'GestureDetector';
        searchForBetter = true;
        searchForText = false;
      }
    }

    if (elementName != null) {
      // A user added annotation takes precedence over a search, but using
      // semantic information from further up the tree is a last resort.
      var elementDescription = treeAnnotation ??
          _findElementInnerText(element, searchForText) ??
          'unknown';
      return _ElementDescription(
        element: element,
        elementName: elementName,
        elementDescription: elementDescription,
        tryForBetter: searchForBetter,
      );
    }

    return null;
  }
}

Element? _findGestureDetectorElement(
    Element rootElement, List<HitTestEntry> hitTargets) {
  final targets = List<HitTestEntry>.from(hitTargets);
  targets.removeLast();

  Element? detectorElement;
  RenderObject? lastRenderObject;

  void elementVisitor(Element element) {
    if (detectorElement != null || targets.isEmpty) return;

    final ro = element.renderObject;
    if (ro == null) return;

    // This is the same logic as above for detecting
    // re-use of render objects
    if (ro == targets.last.target) {
      targets.removeLast();
      lastRenderObject = ro;
    }

    if (ro == lastRenderObject) {
      final widget = element.widget;
      if (widget is GestureDetector) {
        detectorElement = element;
      }

      if (detectorElement == null) {
        element.visitChildElements(elementVisitor);
      }
    } else {
      element.visitChildElements(elementVisitor);
    }
  }

  rootElement.visitChildElements(elementVisitor);

  return detectorElement;
}

/// Provide information on the user actions that can happen in this tree
///
/// Used by the [RumUserActionDetector] to provide descriptions for the user
/// actions it detects in its tree.
///
/// Note, because this will override all actions detected in its child tree, it
/// is best to put it as close to the [GestureDetector] or button that it is
/// providing information about.
@immutable
class RumUserActionAnnotation extends StatelessWidget {
  final String description;
  final Widget child;

  const RumUserActionAnnotation({
    Key? key,
    required this.description,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
