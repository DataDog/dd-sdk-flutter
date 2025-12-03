// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../../datadog_flutter_plugin.dart';
import '../../datadog_internal.dart';
import 'dd_sdk_cpp.dart';

/// This platform is used with any platform that utilizes the Datadog
/// C / C++ Client SDK. This includes Windows and Linux.
class DatadogSdkFfiPlatform extends DatadogSdkPlatform {
  final dd = dd_sdk_cpp(DynamicLibrary.open('libdd_native.so'));

  @internal
  Pointer<dd_core_t>? core;

  @override
  DatadogContext? get cachedContext => null;

  @override
  Future<void> addUserExtraInfo(Map<String, Object?> extraInfo) {
    return Future.value();
  }

  @override
  Future<AttachResponse?> attachToExisting(
    DatadogAttachConfiguration attachConfig,
  ) async {
    return AttachResponse(loggingEnabled: false, rumEnabled: false);
  }

  @override
  Future<void> flushAndDeinitialize() {
    return Future.value();
  }

  @override
  Future<PlatformInitializationResult> initialize(
    DatadogConfiguration configuration,
    TrackingConsent trackingConsent, {
    LogCallback? logCallback,
    required InternalLogger internalLogger,
  }) async {
    using((arena) {
      final cConfig = arena.allocate<dd_core_config>(sizeOf<dd_core_config>());
      final cClientToken =
          configuration.clientToken.toNativeUtf8(allocator: arena);
      // TODO: Default service detection
      final cService =
          (configuration.service ?? 'datadog').toNativeUtf8(allocator: arena);
      final cEnv = configuration.env.toNativeUtf8(allocator: arena);
      dd.dd_core_config_init_func(
          cConfig, cClientToken.cast(), cService.cast(), cEnv.cast());

      cConfig.ref.tracking_consentAsInt = trackingConsent.asFfiInt();
      cConfig.ref.siteAsInt = configuration.site.asFfiInt();
      cConfig.ref.diagnostic_thresholdAsInt =
          dd_diagnostic_level_t.DD_DIAGNOSTIC_LEVEL_DEBUG.value;

      core = dd.dd_core_create(cConfig);
    });

    return PlatformInitializationResult(
        logs: configuration.loggingConfiguration != null,
        rum: configuration.rumConfiguration != null);
  }

  @override
  Future<void> start() async {
    dd.dd_core_start(core!);
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
  Future<void> setSdkVerbosity(CoreLoggerLevel verbosity) {
    return Future.value();
  }

  @override
  Future<void> setTrackingConsent(TrackingConsent trackingConsent) async {
    if (core case final core?) {
      dd.dd_core_set_tracking_consent(core, trackingConsent.asFfiEnum());
    }
  }

  @override
  Future<void> setUserInfo(
    String? id,
    String? name,
    String? email,
    Map<String, Object?> extraInfo,
  ) {
    return Future.value();
  }

  @override
  Future<void> updateTelemetryConfiguration(String property, bool value) {
    return Future.value();
  }

  @override
  Future<void> clearAllData() {
    return Future.value();
  }

  @override
  Future<void> addAccountExtraInfo(Map<String, Object?> extraInfo) {
    return Future.value();
  }

  @override
  Future<void> clearAccountInfo() {
    return Future.value();
  }

  @override
  Future<void> clearUserInfo() {
    return Future.value();
  }

  @override
  Future<void> setAccountInfo(
    String id,
    String? name,
    Map<String, Object?> extraInfo,
  ) {
    return Future.value();
  }

  @override
  Future<IsolateAttachResponse?> attachToIsolate() {
    return Future.value(null);
  }
}

extension on DatadogSite {
  int asFfiInt() {
    switch (this) {
      case DatadogSite.us1:
        return dd_site_t.DD_SITE_US1.value;
      case DatadogSite.us3:
        return dd_site_t.DD_SITE_US3.value;
      case DatadogSite.us5:
        return dd_site_t.DD_SITE_US5.value;
      case DatadogSite.eu1:
        return dd_site_t.DD_SITE_EU1.value;
      case DatadogSite.us1Fed:
        return dd_site_t.DD_SITE_US1_FED.value;
      case DatadogSite.ap1:
        return dd_site_t.DD_SITE_AP1.value;
      case DatadogSite.ap2:
        return dd_site_t.DD_SITE_AP2.value;
    }
  }
}

extension on TrackingConsent {
  dd_tracking_consent_t asFfiEnum() {
    switch (this) {
      case TrackingConsent.granted:
        return dd_tracking_consent_t.DD_TRACKING_CONSENT_GRANTED;
      case TrackingConsent.notGranted:
        return dd_tracking_consent_t.DD_TRACKING_CONSENT_NOT_GRANTED;
      case TrackingConsent.pending:
        return dd_tracking_consent_t.DD_TRACKING_CONSENT_PENDING;
    }
  }

  int asFfiInt() {
    return asFfiEnum().value;
  }
}
