// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';

import '../datadog_tracking_http_client.dart';

class DdHttpTrackingPluginConfiguration extends DatadogPluginConfiguration {
  final Set<TracingHeaderType>? tracingHeaderTypes;

  DdHttpTrackingPluginConfiguration({required this.tracingHeaderTypes});

  @override
  DatadogPlugin create(DatadogSdk datadogInstance) {
    return _DdHttpTrackingPlugin(datadogInstance, this);
  }
}

class _DdHttpTrackingPlugin extends DatadogPlugin {
  final DdHttpTrackingPluginConfiguration configuration;

  _DdHttpTrackingPlugin(
    DatadogSdk datadogInstance,
    this.configuration,
  ) : super(datadogInstance);

  @override
  void initialize() {
    HttpOverrides.global =
        DatadogTrackingHttpOverrides(instance, configuration);
    instance.updateConfigurationInfo(
        LateConfigurationProperty.trackNetworkRequests, true);
  }
}
