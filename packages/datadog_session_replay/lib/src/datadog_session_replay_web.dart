// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
// ignore: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import '../datadog_session_replay.dart';
import 'datadog_session_replay_platform_interface.dart';
import 'rum_context.dart';

/// A stub implementation for Flutter Session Replay for Web. Datadog Session
/// Replay is not currently supported for the Flutter Web.
class DatadogSessionReplayWeb extends DatadogSessionReplayPlatform {
  /// Constructs a DatadogSessionReplayWeb
  DatadogSessionReplayWeb();

  static void registerWith(Registrar registrar) {
    DatadogSessionReplayPlatform.instance = DatadogSessionReplayWeb();
  }

  @override
  Object? get isolateToken => null;

  @override
  Future<bool> enable(
    DatadogSessionReplayConfiguration configuration,
    void Function(RUMContext p1) onContextChanged,
  ) {
    return Future.value(false);
  }

  @override
  Future<void> setHasReplay(String viewId, bool hasReplay) {
    return Future.value();
  }

  @override
  Future<void> setRecordCount(String viewId, int count) {
    return Future.value();
  }

  @override
  Future<void> writeSegment(String record, String viewId) {
    return Future.value();
  }

  @override
  FutureOr<void> telemetryDebug(String id, String message) {
    // Not currently supported
  }

  @override
  FutureOr<void> telemetryError(String message, String kind, String stack) {
    // Not currently supported
  }

  @override
  String? resourceIdForKey(int resourceKey) {
    return null;
  }

  @override
  FutureOr<void> saveImageForProcessing(
    int resourceKey,
    int width,
    int height,
    ByteData byteData,
  ) {}
}
