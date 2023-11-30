// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../datadog_session_replay.dart';
import 'datadog_session_replay_method_channel.dart';

abstract class DatadogSessionReplayPlatform extends PlatformInterface {
  /// Constructs a DatadogSessionReplayPlatform.
  DatadogSessionReplayPlatform() : super(token: _token);

  static final Object _token = Object();

  static DatadogSessionReplayPlatform _instance =
      MethodChannelDatadogSessionReplay();

  /// The default instance of [DatadogSessionReplayPlatform] to use.
  ///
  /// Defaults to [MethodChannelDatadogSessionReplay].
  static DatadogSessionReplayPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DatadogSessionReplayPlatform] when
  /// they register themselves.
  static set instance(DatadogSessionReplayPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> enable(DatadogSessionReplayConfiguration configuration,
      void Function(RUMContext) onContextChanged);

  Future<void> setHasReplay(bool hasReplay);

  Future<void> setRecordCount(String viewId, int count);

  Future<void> writeSegment(String record, String viewId);
}
