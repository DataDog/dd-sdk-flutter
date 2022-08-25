// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../datadog_flutter_plugin.dart';
import 'datadog_sdk_method_channel.dart';

typedef LogCallback = void Function(String line);

abstract class DatadogSdkPlatform extends PlatformInterface {
  DatadogSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static DatadogSdkPlatform _instance = DatadogSdkMethodChannel();

  static DatadogSdkPlatform get instance => _instance;

  static set instance(DatadogSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> setSdkVerbosity(Verbosity verbosity);
  Future<void> setTrackingConsent(TrackingConsent trackingConsent);
  Future<void> setUserInfo(
      String? id, String? name, String? email, Map<String, Object?> extraInfo);

  Future<void> sendTelemetryDebug(String message);
  Future<void> sendTelemetryError(String message, String? stack, String? kind);

  Future<void> initialize(DdSdkConfiguration configuration,
      {LogCallback? logCallback});
  Future<void> flushAndDeinitialize();
}
