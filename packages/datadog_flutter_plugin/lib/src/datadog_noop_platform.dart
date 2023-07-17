// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import '../datadog_internal.dart';
import 'datadog_configuration.dart';

class DatadogSdkNoOpPlatform extends DatadogSdkPlatform {
  @override
  Future<void> addUserExtraInfo(Map<String, Object?> extraInfo) {
    return Future.value();
  }

  @override
  Future<AttachResponse?> attachToExisting() async {
    return AttachResponse(rumEnabled: false);
  }

  @override
  Future<void> flushAndDeinitialize() {
    return Future.value();
  }

  @override
  Future<void> initialize(DdSdkConfiguration configuration,
      {LogCallback? logCallback, required InternalLogger internalLogger}) {
    return Future.value();
  }

  @override
  Future<void> sendTelemetryDebug(String message) {
    return Future.value();
  }

  @override
  Future<void> sendTelemetryError(String message, String? stack, String? kind) {
    return Future.value();
  }

  @override
  Future<void> setSdkVerbosity(Verbosity verbosity) {
    return Future.value();
  }

  @override
  Future<void> setTrackingConsent(TrackingConsent trackingConsent) {
    return Future.value();
  }

  @override
  Future<void> setUserInfo(
      String? id, String? name, String? email, Map<String, Object?> extraInfo) {
    return Future.value();
  }

  @override
  Future<void> updateTelemetryConfiguration(String property, bool value) {
    return Future.value();
  }
}
