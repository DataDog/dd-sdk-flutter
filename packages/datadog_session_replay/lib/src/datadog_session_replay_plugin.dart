// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

// ignore_for_file: invalid_use_of_internal_member

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';

import '../datadog_session_replay.dart';

class DatadogSessionReplayPluginConfiguration
    extends DatadogPluginConfiguration {
  DatadogSessionReplayConfiguration configuration;

  DatadogSessionReplayPluginConfiguration({required this.configuration});

  @override
  DatadogPlugin create(DatadogSdk datadogInstance) {
    return _SessionReplayPlugin(datadogInstance, configuration);
  }
}

class _SessionReplayPlugin extends DatadogPlugin {
  final DatadogSessionReplayConfiguration configuration;

  _SessionReplayPlugin(super.instance, this.configuration);

  @override
  Future<void> initialize() async {
    await wrapAsync(
        '_SessionReplayPlugin.initialize', instance.internalLogger, null,
        () async {
      await DatadogSessionReplay.init(configuration);
      instance.internalLogger.debug('Flutter Session Replay Enabled');
    });
  }
}
