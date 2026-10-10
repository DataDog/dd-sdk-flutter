// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flutter_plugin_platform_interface/datadog_flutter_plugin_platform_interface.dart'
    as pi
    show DatadogPluginConfiguration;
import 'package:flutter/material.dart';

import 'datadog_sdk.dart';

abstract class DatadogPluginConfiguration
    extends pi.DatadogPluginConfiguration {
  const DatadogPluginConfiguration();

  DatadogPlugin create(DatadogSdk datadogInstance);
}

abstract class DatadogPlugin {
  @protected
  final DatadogSdk instance;

  DatadogPlugin(this.instance);

  void initialize();
  void initializeFromBackgroundIsolate() {
    initialize();
  }

  void shutdown() {}
}
