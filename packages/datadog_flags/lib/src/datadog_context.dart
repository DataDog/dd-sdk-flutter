// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/foundation.dart';

class DatadogFlagsContext {
  final String clientToken;
  final String env;
  final DatadogSite site;
  final String? service;
  final String? version;
  final String? applicationId;
  final String sdkVersion;
  final String source;

  const DatadogFlagsContext({
    required this.clientToken,
    required this.env,
    required this.site,
    required this.sdkVersion,
    this.service,
    this.version,
    this.applicationId,
    this.source = 'flutter',
  });

  factory DatadogFlagsContext.fromSdk(DatadogSdk sdk) {
    final configuration = sdk.configuration;
    if (configuration == null) {
      throw StateError(
        'DatadogSdk must be initialized before enabling DatadogFlags.',
      );
    }

    return DatadogFlagsContext(
      clientToken: configuration.clientToken,
      env: configuration.env,
      site: configuration.site,
      service: configuration.service,
      version: configuration.versionTag,
      applicationId: configuration.rumConfiguration?.applicationId,
      sdkVersion: DatadogSdk.sdkVersion,
    );
  }

  Uri flagsEndpoint() {
    return switch (site) {
      DatadogSite.us1 => Uri.parse('https://preview.ff-cdn.datadoghq.com'),
      DatadogSite.us3 => Uri.parse('https://preview.ff-cdn.us3.datadoghq.com'),
      DatadogSite.us5 => Uri.parse('https://preview.ff-cdn.us5.datadoghq.com'),
      DatadogSite.eu1 => Uri.parse('https://preview.ff-cdn.datadoghq.eu'),
      DatadogSite.ap1 => Uri.parse('https://preview.ff-cdn.ap1.datadoghq.com'),
      DatadogSite.ap2 => Uri.parse('https://preview.ff-cdn.ap2.datadoghq.com'),
      DatadogSite.us1Fed => Uri.parse('https://preview.ff-cdn.datadoghq.com'),
    };
  }

  Uri intakeEndpoint() {
    return switch (site) {
      DatadogSite.us1 => Uri.parse('https://browser-intake-datadoghq.com'),
      DatadogSite.us3 => Uri.parse('https://browser-intake-us3-datadoghq.com'),
      DatadogSite.us5 => Uri.parse('https://browser-intake-us5-datadoghq.com'),
      DatadogSite.eu1 => Uri.parse('https://browser-intake-datadoghq.eu'),
      DatadogSite.ap1 => Uri.parse('https://browser-intake-ap1-datadoghq.com'),
      DatadogSite.ap2 => Uri.parse('https://browser-intake-ap2-datadoghq.com'),
      DatadogSite.us1Fed => Uri.parse('https://browser-intake-ddog-gov.com'),
    };
  }

  Map<String, Object?> evaluationBatchContext() {
    final rumContext = applicationId == null
        ? null
        : {
            'application': {'id': applicationId},
            'view': null,
          };

    return removeNullValues({
      'geo': null,
      'device': {
        'name': defaultTargetPlatform.name,
        'type': _deviceTypeForTargetPlatform(defaultTargetPlatform),
        'brand': '',
        'model': defaultTargetPlatform.name,
      },
      'os': {
        'name': defaultTargetPlatform.name,
        'version': '',
      },
      'service': service ?? '',
      'version': version ?? '',
      'env': env,
      'rum': rumContext,
    });
  }
}

String _deviceTypeForTargetPlatform(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android || TargetPlatform.iOS => 'mobile',
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      'desktop',
    TargetPlatform.fuchsia => 'other',
  };
}

Map<String, Object?> removeNullValues(Map<String, Object?> input) {
  return Map.fromEntries(input.entries.where((entry) => entry.value != null));
}
