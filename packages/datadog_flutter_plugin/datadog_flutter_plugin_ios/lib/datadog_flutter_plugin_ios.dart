// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart';

import 'src/datadog_sdk_method_channel.dart';
import 'src/logs/ddlogs_method_channel.dart';
import 'src/rum/ddrum_method_channel.dart';

export 'src/datadog_sdk_method_channel.dart';

class DatadogFlutterPluginIos {
  static void registerWith() {
    DatadogSdkPlatform.instance = DatadogSdkMethodChannel();
    DdLogsPlatform.instance = DdLogsMethodChannel();
    DdRumPlatform.instance = DdRumMethodChannel();
  }
}
