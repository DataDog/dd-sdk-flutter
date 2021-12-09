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
  Future<void> initialize(DdSdkConfiguration configuration) async {}

  @override
  DdLogs get ddLogs => DdLogsWeb();
}

class DdLogsWeb extends DdLogs {
  @override
  Future<void> debug(String message,
      [Map<String, Object?> context = const {}]) {
    // TODO: implement debug
    throw UnimplementedError();
  }

  @override
  Future<void> error(String message,
      [Map<String, Object?> context = const {}]) {
    // TODO: implement error
    throw UnimplementedError();
  }

  @override
  Future<void> info(String message, [Map<String, Object?> context = const {}]) {
    // TODO: implement info
    throw UnimplementedError();
  }

  @override
  Future<void> warn(String message, [Map<String, Object?> context = const {}]) {
    // TODO: implement warn
    throw UnimplementedError();
  }
}
