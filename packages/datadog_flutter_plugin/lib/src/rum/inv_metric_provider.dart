// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:meta/meta.dart';

import '../../datadog_flutter_plugin.dart';
import '../../datadog_internal.dart';

// Max time in seconds
const double defaultMaxTimeToNextView = 3.0;

/// Tracks actions in views in order to provide a custom Interaction To Next View (INV)
/// value. INV in Flutter is calculated as the time from when a user takes an action
/// until the "First Build Complete" on a new view.
class InvMetricProvider {
  final Map<String, _InvViewInfo> _views = {};
  // _curentView can hold a stopped view, so should not be used to see what the
  // current active view is.
  _InvViewInfo? _currentView;

  void trackViewStart(String viewKey, DateTime timestamp) {
    final newView = _InvViewInfo(viewKey, _currentView?.viewKey, timestamp);
    if (_currentView case final currentView?) {
      trackViewStop(currentView.viewKey, timestamp);
    }
    _currentView = newView;
    _views[viewKey] = newView;
  }

  void trackViewStop(String viewKey, DateTime timestamp) {
    final view = _views[viewKey];
    if (view != null) {
      view.endTime = timestamp;
      if (view.previousViewKey case final previousViewKey?) {
        // The view before this shouldn't be required anymore.
        _views.remove(previousViewKey);
      }
    }
  }

  void trackAction(
      String viewKey, DateTime startTime, RumActionType actionType) {
    final view = _views[viewKey];
    if (view == null) return;

    view.actionLog.add(_AcitonInfo(startTime, actionType));
  }

  void trackViewFirstBuildComplete(String viewKey, DateTime timestamp) {
    final view = _views[viewKey];
    if (view == null) return;

    view.firstBuildCompleteTime = timestamp;
  }

  /// Time in nanoseconds from the last interaction on the previous view to the moment the current view was finished building.
  int? valueForView(String viewKey) {
    final view = _views[viewKey];
    if (view == null) return null;
    if (view.previousViewKey == null) return null;
    if (view.firstBuildCompleteTime == null) return null;

    final previousView = _views[view.previousViewKey];
    if (previousView == null) return null;

    final lastAction = _findLastValidActionBefore(
      view.firstBuildCompleteTime!,
      previousView.actionLog,
      defaultMaxTimeToNextView,
    );
    if (lastAction == null) return null;

    final duration =
        view.firstBuildCompleteTime!.difference(lastAction.startTime);

    return duration.inNanoseconds;
  }

  // Max is in total seconds
  _AcitonInfo? _findLastValidActionBefore(
      DateTime time, List<_AcitonInfo> actions, double max) {
    final maxDuration =
        Duration(microseconds: (max * Duration.microsecondsPerSecond).toInt());
    for (final action in actions.reversed) {
      final duration = time.difference(action.startTime);
      if (duration.isNegative) continue;

      // Stuff from here back will be even older
      if (duration > maxDuration) return null;

      if (action.actionType == RumActionType.tap ||
          action.actionType == RumActionType.swipe) {
        return action;
      }
    }
    return null;
  }
}

class _InvViewInfo {
  final String viewKey;
  final String? previousViewKey;
  final DateTime startTime;
  DateTime? firstBuildCompleteTime;
  DateTime? endTime;
  double? invTime;

  final List<_AcitonInfo> actionLog = [];

  _InvViewInfo(this.viewKey, this.previousViewKey, this.startTime);
}

@immutable
class _AcitonInfo {
  final DateTime startTime;
  final RumActionType actionType;

  const _AcitonInfo(this.startTime, this.actionType);
}
