// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:async';
// ignore: unused_import
import 'dart:html' as html show window;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'src/datadog_configuration.dart';
import 'src/datadog_sdk_platform_interface.dart';
import 'src/logs/ddlogs_platform_interface.dart';
import 'src/logs/ddlogs_web.dart';

/// A web implementation of the DatadogSdk plugin.
class DatadogSdkWeb extends DatadogSdkPlatform {
  static void registerWith(Registrar registrar) {
    DatadogSdkPlatform.instance = DatadogSdkWeb();

    DdLogsPlatform.instance = DdLogsWeb();
  }

  @override
  Future<void> setSdkVerbosity(Verbosity verbosity) async {}

  @override
  Future<void> setTrackingConsent(TrackingConsent trackingConsent) async {}

  @override
  Future<void> setUserInfo(String? id, String? name, String? email,
      Map<String, dynamic> extraInfo) async {}

  @override
  Future<void> initialize(DdSdkConfiguration configuration,
      {LogCallback? logCallback}) async {
    if (configuration.loggingConfiguration != null) {
      DdLogsWeb.initLogs(configuration);
    }
  }

  @override
  Future<void> flushAndDeinitialize() async {}
}
