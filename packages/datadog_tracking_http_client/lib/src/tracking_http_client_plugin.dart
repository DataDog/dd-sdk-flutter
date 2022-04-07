// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

import '../datadog_tracking_http_client.dart';

class DdHttpTrackingPluginConfiguration extends DatadogPluginConfiguration {
  @override
  DatadogPlugin create(DatadogSdk datadogInstance) {
    return _DdHttpTrackingPlugin(datadogInstance);
  }
}

class _DdHttpTrackingPlugin extends DatadogPlugin {
  _DdHttpTrackingPlugin(DatadogSdk datadogInstance) : super(datadogInstance);

  @override
  void initialize() {
    HttpOverrides.global = DatadogTrackingHttpOverrides(DatadogSdk.instance);
  }
}
