// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'datadog_flutter_plugin.dart';
import 'src/datadog_sdk_platform_interface.dart';
import 'src/internal_logger.dart';
import 'src/logs/ddlogs_platform_interface.dart';
import 'src/logs/ddlogs_web.dart';
import 'src/rum/ddrum_platform_interface.dart';
import 'src/rum/ddrum_web.dart';

/// A web implementation of the DatadogSdk plugin.
class DatadogSdkWeb extends DatadogSdkPlatform {
  static void registerWith(Registrar registrar) {
    DatadogSdkPlatform.instance = DatadogSdkWeb();

    DdLogsPlatform.instance = DdLogsWeb();
    DdRumPlatform.instance = DdRumWeb();
  }

  @override
  Future<void> setSdkVerbosity(CoreLoggerLevel verbosity) async {}

  @override
  Future<void> setTrackingConsent(TrackingConsent trackingConsent) async {}

  @override
  Future<void> setUserInfo(String? id, String? name, String? email,
      Map<String, dynamic> extraInfo) async {
    // TODO: Extra user properties
    DD_RUM?.setUser(JsUser(
      id: id,
      name: name,
      email: email,
    ));
  }

  @override
  Future<void> addUserExtraInfo(Map<String, Object?> extraInfo) async {}

  @override
  Future<PlatformInitializationResult> initialize(
    DatadogConfiguration configuration,
    TrackingConsent trackingConsent, {
    LogCallback? logCallback,
    required InternalLogger internalLogger,
  }) async {
    bool logsInitialized = false;
    try {
      if (configuration.loggingConfiguration != null) {
        DdLogsWeb.initLogs(configuration);
        logsInitialized = true;
      }
    } catch (e) {
      internalLogger.warn('DatadogSdk failed to initialize logging: $e');
      internalLogger
          .warn('Did you remember to add "datadog-logs" to your scripts?');
    }

    bool rumInitialized = false;
    try {
      if (configuration.rumConfiguration != null) {
        final rumWeb = DdRumPlatform.instance as DdRumWeb;
        rumWeb.initialize(
          configuration,
          configuration.rumConfiguration!,
          internalLogger,
        );
        rumInitialized = true;
      }
    } catch (e) {
      internalLogger.warn('DatadogSdk failed to initialize RUM: $e');
      internalLogger
          .warn('Did you remember to add "datadog-rum-slim" to your scripts?');
    }

    return PlatformInitializationResult(
        logs: logsInitialized, rum: rumInitialized);
  }

  @override
  Future<AttachResponse?> attachToExisting() async {
    return null;
  }

  @override
  Future<void> flushAndDeinitialize() async {}

  @override
  Future<void> sendTelemetryDebug(String message) async {
    // Not currently supported
  }

  @override
  Future<void> sendTelemetryError(
      String message, String? stack, String? kind) async {
    // Not currently supported
  }

  @override
  Future<void> updateTelemetryConfiguration(String property, bool value) async {
    // Not currently supported
  }

  @override
  Future<void> clearAllData() async {
    // Not currently supported
  }
}
