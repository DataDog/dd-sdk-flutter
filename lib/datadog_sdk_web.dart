// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.
import 'dart:async';

import 'dart:html' as html show window;

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:datadog_sdk/datadog_sdk_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// A web implementation of the DatadogSdk plugin.
class DatadogSdkWeb extends DatadogSdkPlatform {
  static void registerWith(Registrar registrar) {
    DatadogSdkPlatform.instance = DatadogSdkWeb();
  }

  @override
  Future<void> initialize(DdSdkConfiguration configuraiton) async {}
}
