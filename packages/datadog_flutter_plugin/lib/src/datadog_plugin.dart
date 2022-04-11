// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../datadog_flutter_plugin.dart';

abstract class DatadogPluginConfiguration {
  DatadogPlugin create(DatadogSdk datadogInstance);
}

abstract class DatadogPlugin {
  @protected
  final DatadogSdk instance;

  DatadogPlugin(this.instance);

  void initialize();
}
