// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flutter_plugin_platform_interface/datadog_flutter_plugin_platform_interface.dart'
    as pi show DatadogPluginConfiguration;
import 'package:flutter/material.dart';

import 'datadog_sdk.dart';

abstract class DatadogPluginConfiguration extends pi.DatadogPluginConfiguration {
  DatadogPlugin create(DatadogSdk datadogInstance);

  /// Indicate that this plugin can be used from and initialized from background
  /// isolates when [DatadogSdk.attachToBackgroundIsolate] is called. Plugins
  /// that have this set to `true` will have
  /// [DatadogPlugin.initializeFromBackgroundIsolate] called when background
  /// isolate is attached, which by default calls [DatadogPlugin.initialize].
  ///
  /// Any subclass that has this flag set to `true` must also be marked as
  /// [immutable] so that the configuration can be sent to the background isolate.
  ///
  /// If this flag is set to `false` (the default), no initialization of the
  /// plugin will occur when Datadog is attached to a background isolate, which
  /// may mean the features of this plugin will not be available.
  @override
  bool get supportsBackgroundIsolates => false;
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
