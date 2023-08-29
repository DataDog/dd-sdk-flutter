// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../../datadog_flutter_plugin.dart';
import '../helpers.dart';

class RumLongTaskObserver with WidgetsBindingObserver {
  // The amount of elapsed time that is considered to be a "long task", in seconds.
  final double longTaskThreshold;
  final DdRum? rumInstance;

  var _detectingLongTasks = false;
  Future<void>? _longTaskDetectorFuture;

  RumLongTaskObserver({
    this.longTaskThreshold = 0.1,
    this.rumInstance,
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _startLongTaskDetection();
        break;
      case AppLifecycleState.inactive:
        stopLongTaskDetection();
        break;
      case AppLifecycleState.paused:
        stopLongTaskDetection();
        break;
      case AppLifecycleState.detached:
        stopLongTaskDetection();
        break;
      case AppLifecycleState.hidden:
        stopLongTaskDetection();
        break;
    }
  }

  void init() {
    ambiguate(WidgetsBinding.instance)?.addObserver(this);
    _startLongTaskDetection();
  }

  void dispose() {
    ambiguate(WidgetsBinding.instance)?.removeObserver(this);
  }

  void _startLongTaskDetection() async {
    if (!_detectingLongTasks) {
      // We were in the process of stopping this, wait for
      // it to finish before starting it up again
      if (_longTaskDetectorFuture != null) {
        await _longTaskDetectorFuture;
      }
      _detectingLongTasks = true;
      _longTaskDetectorFuture = _longTaskDetector();
    }
  }

  @visibleForTesting
  Future<void> stopLongTaskDetection() async {
    if (_detectingLongTasks) {
      _detectingLongTasks = false;
      await _longTaskDetectorFuture;
      _longTaskDetectorFuture = null;
    }
  }

  Future<void> _longTaskDetector() async {
    final millisecondThreshold = longTaskThreshold * 1000;
    var lastCheck = DateTime.now().millisecondsSinceEpoch;
    while (_detectingLongTasks) {
      await Future<void>.delayed(const Duration(milliseconds: 13));
      final check = DateTime.now().millisecondsSinceEpoch;
      final taskLength = check - lastCheck;
      if (_detectingLongTasks) {
        if (check - lastCheck > millisecondThreshold) {
          rumInstance?.reportLongTask(taskLength);
        }
      }
      lastCheck = check;
    }
  }
}
