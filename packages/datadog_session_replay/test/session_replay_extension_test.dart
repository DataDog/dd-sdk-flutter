// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sessionReplayConfiguration = DatadogSessionReplayConfiguration(
    replaySampleRate: 42,
    isEmbedded: true,
  );

  test('enableSessionReplay adds the plugin W DatadogConfiguration', () {
    // Given
    final configuration = DatadogConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      service: 'service',
      site: DatadogSite.us1,
    );

    // When
    configuration.enableSessionReplay(sessionReplayConfiguration);

    // Then
    final plugin =
        configuration.additionalPlugins.single
            as DatadogSessionReplayPluginConfiguration;
    expect(plugin.configuration, same(sessionReplayConfiguration));
  });

  test('enableSessionReplay adds the plugin W DatadogAttachConfiguration', () {
    // Given
    final configuration = DatadogAttachConfiguration();

    // When
    configuration.enableSessionReplay(sessionReplayConfiguration);

    // Then
    final plugin =
        configuration.additionalPlugins.single
            as DatadogSessionReplayPluginConfiguration;
    expect(plugin.configuration, same(sessionReplayConfiguration));
  });
}
