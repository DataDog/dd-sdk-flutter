// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import 'datadog_sdk_platform_interface.dart';

class DatadogSdkMethodChannel extends DatadogSdkPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel("datadog_sdk_flutter");

  @override
  Future<void> initialize(DdSdkConfiguration configuration) async {
    await methodChannel.invokeMethod(
        'DdSdk.initialize', {'configuration': configuration.encode()});
  }
}
