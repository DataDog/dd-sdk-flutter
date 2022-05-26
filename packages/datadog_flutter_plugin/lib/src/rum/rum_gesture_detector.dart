// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../../datadog_flutter_plugin.dart';

// The distance a 'pointer' can move and still be considered a tap.
const _tapSlop = 20;
const _tapSlopSquared = _tapSlop * _tapSlop;

@immutable
class _ElementDescription {
  final Element element;
  final String elementDescription;

  const _ElementDescription(
    this.element,
    this.elementDescription,
  );
}

/// Detect simple user actions and send them to RUM.
///
/// This wrapper widget automatically detects simple user actions (taps and
/// swipes) that occur in its tree and sends them to RUM. It detects
/// interactions with several common Flutter widgets, including
/// [ElevatedButton], [TextButton], [InkWell], and [GestureDetector].
///
/// For most Button types, the detector will look for a [Text] widget child,
/// which it will use for the description of the action. In other cases, it will
/// look for a child [Semantics] object, or an [Icon] with its [semanticsLabel]
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
  final _listenerKey = GlobalKey();

  int? _lastPointerId;
  Offset? _lastPointerDownLocation;

  @override
  void didUpdateWidget(covariant RumUserActionDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    var element = RumUserActionDetector.elementMap[oldWidget];
    if (element != null) {
      RumUserActionDetector.elementMap.remove(oldWidget);
      RumUserActionDetector.elementMap[widget] = element;
    } else {
      // Telemetry -- this shouldn't happen
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
      widget.rum?.addUserAction(
          RumUserActionType.tap, elementDescription.elementDescription);
    }
  }

  String _findElementInnerText(Element element, bool allowText) {
    var elementDescription = 'unknown';

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

    _ElementDescription? detectingElement;
    String? rumTreeAnnotation;

    void elementVisitor(Element element) {
      // We already have a candidate element, you can stop now
      if (detectingElement != null) return;

      final ro = element.renderObject;
      if (ro == null) return;

      final transform = ro.getTransformTo(rootElement.renderObject);
      final paintBounds = MatrixUtils.transformRect(transform, ro.paintBounds);

      if (paintBounds.contains(position)) {
        final widget = element.widget;
        if (widget is RumUserActionAnnotation) {
          rumTreeAnnotation = widget.description;
        } else {
          detectingElement =
              _getDetectingElementDescription(element, rumTreeAnnotation);
        }

        if (detectingElement == null) {
          element.visitChildElements(elementVisitor);
        }
        // This annotation was only for this tree
        rumTreeAnnotation = null;
      }
    }

    rootElement.visitChildElements(elementVisitor);

    return detectingElement;
  }

  _ElementDescription? _getDetectingElementDescription(
      Element element, String? treeAnnotation) {
    final widget = element.widget;
    if (widget is ButtonStyleButton) {
      if (widget.enabled) {
        final innerDescription =
            treeAnnotation ?? _findElementInnerText(element, true);
        return _ElementDescription(element, 'Button($innerDescription)');
      }
    } else if (widget is MaterialButton) {
      if (widget.enabled) {
        final innerDescription =
            treeAnnotation ?? _findElementInnerText(element, true);
        return _ElementDescription(element, 'Button($innerDescription)');
      }
    } else if (widget is CupertinoButton) {
      if (widget.enabled) {
        final innerDescription =
            treeAnnotation ?? _findElementInnerText(element, true);
        return _ElementDescription(element, 'Button($innerDescription)');
      }
    } else if (widget is InkWell) {
      if (widget.onTap != null) {
        final innerDescription =
            treeAnnotation ?? _findElementInnerText(element, false);
        return _ElementDescription(element, 'InkWell($innerDescription)');
      }
    } else if (widget is IconButton) {
      if (widget.onPressed != null) {
        final innerDescription =
            treeAnnotation ?? _findElementInnerText(element, false);
        return _ElementDescription(element, 'IconButton($innerDescription)');
      }
    } else if (widget is GestureDetector) {
      if (widget.onTap != null) {
        final innerDescription = treeAnnotation ?? 'unknown';
        return _ElementDescription(
            element, 'GestureDetector($innerDescription)');
      }
    }

    return null;
  }
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
