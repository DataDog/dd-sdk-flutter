import 'dart:async';

import 'dart:html' as html show window;

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:datadog_sdk/datadog_sdk_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// A web implementation of the DatadogSdk plugin.
class DatadogSdkWeb extends DatadogSdkPlatform  {
  static void registerWith(Registrar registrar) {
    DatadogSdkPlatform.instance = DatadogSdkWeb();
  }

  @override
  Future<void> initialize(DdSdkConfiguration configuraiton) async {

  }
}
