// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

import 'src/datadog_session_replay_plugin.dart';

export 'src/capture/session_replay_capture.dart';
// TODO: Remove this export
export 'src/datadog_session_replay.dart';

enum SessionReplayPrivacyLevel { allow, mask, maskUserInput }

class DatadogSessionReplayConfiguration {
  double replaySampleRate;
  SessionReplayPrivacyLevel defaultPrivacyLevel;
  String? customEndpoint;

  DatadogSessionReplayConfiguration({
    required this.replaySampleRate,
    this.defaultPrivacyLevel = SessionReplayPrivacyLevel.mask,
    this.customEndpoint,
  });
}

extension SessionReplayExtension on DatadogConfiguration {
  void enableSessionReplay(DatadogSessionReplayConfiguration config) {
    addPlugin(DatadogSessionReplayPluginConfiguration(configuration: config));
  }
}
