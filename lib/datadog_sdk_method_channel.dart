import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import 'datadog_sdk_platform_interface.dart';

class DatadogSdkMethodChannel extends DatadogSdkPlatform {
  
  @visibleForTesting
  final methodChannel = const MethodChannel("datadog_sdk_flutter");

  @override
  Future<void> initialize(DdSdkConfiguration configuration) async {
    await methodChannel.invokeMethod('DdSdk.initialize', {
      'configuration': configuration.encode()
    });
  }
}