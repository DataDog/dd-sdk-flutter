// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'datadog_sdk_method_channel.dart';

abstract class DatadogSdkPlatform extends PlatformInterface {
  DatadogSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static DatadogSdkPlatform _instance = DatadogSdkMethodChannel();

  /// The default instance of [{{pluginDartClass}}Platform] to use.
  ///
  /// Defaults to [MethodChannel{{pluginDartClass}}].
  static DatadogSdkPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [{{pluginDartClass}}Platform] when they register themselves.
  static set instance(DatadogSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize(DdSdkConfiguration configuration);
}
