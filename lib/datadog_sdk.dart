// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.
// ignore_for_file: unused_element, unused_field

import 'datadog_sdk_platform_interface.dart';
import 'logs/ddlogs.dart';
import 'version.dart' show ddSdkVersion;

class DdSdkConfiguration {
  String clientToken;
  String env;
  String? applicationId;
  bool nativeCrashReportEnabled;
  double sampleRate;
  String? site;
  String? trackingConsent;
  String? customEndpoint;
  Map<String, dynamic> additionalConfig = {};

  DdSdkConfiguration({
    required this.clientToken,
    required this.env,
    this.applicationId,
    this.nativeCrashReportEnabled = false,
    this.sampleRate = 100.0,
    this.site,
    this.customEndpoint,
    this.trackingConsent,
  });

  Map<String, dynamic> encode() {
    return {
      'clientToken': clientToken,
      'env': env,
      'applicationId': applicationId,
      'nativeCrashReportEnabled': nativeCrashReportEnabled,
      'sampleRate': sampleRate,
      'site': site,
      'trackingConsent': trackingConsent,
      'customEndpoint': customEndpoint,
      'additionalConfig': additionalConfig
    };
  }
}

class _DatadogConfigKey {
  static const source = '_dd.source';
  static const version = '_dd.sdk_version';
  static const serviceName = '_dd.service_name';
  static const verbosity = '_dd.sdk_verbosity';
  static const nativeViewTracking = '_dd.native_view_tracking';
}

class DatadogSdk {
  static DatadogSdkPlatform get _platform {
    return DatadogSdkPlatform.instance;
  }

  static DatadogSdk? _singleton;
  factory DatadogSdk() {
    _singleton ??= DatadogSdk._();
    return _singleton!;
  }

  DatadogSdk._();

  DdLogs? _ddLogs;
  DdLogs? get ddLogs => _ddLogs;

  Future<void> initialize(DdSdkConfiguration configuration) async {
    configuration.additionalConfig[_DatadogConfigKey.source] = 'flutter';
    configuration.additionalConfig[_DatadogConfigKey.version] = ddSdkVersion;

    await _platform.initialize(configuration);

    _ddLogs = DdLogs();
  }
}
