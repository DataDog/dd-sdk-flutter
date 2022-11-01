// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

// ignore_for_file: unused_element

@JS('DD_RUM')
library ddrum_flutter_web;

import 'dart:async';
// ignore: unused_import
import 'dart:html' as html show window;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:js/js.dart';

import 'src/datadog_configuration.dart';
import 'src/datadog_sdk_platform_interface.dart';
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
  Future<void> setSdkVerbosity(Verbosity verbosity) async {}

  @override
  Future<void> setTrackingConsent(TrackingConsent trackingConsent) async {}

  @override
  Future<void> setUserInfo(String? id, String? name, String? email,
      Map<String, dynamic> extraInfo) async {
    // TODO: Extra user properties
    _jsSetUser(_JsUser(
      id: id,
      name: name,
      email: email,
    ));
  }

  @override
  Future<void> addUserExtraInfo(Map<String, Object?> extraInfo) async {}

  @override
  Future<void> initialize(DdSdkConfiguration configuration,
      {LogCallback? logCallback}) async {
    if (configuration.loggingConfiguration != null) {
      DdLogsWeb.initLogs(configuration);
    }
    if (configuration.rumConfiguration != null) {
      final rumWeb = DdRumPlatform.instance as DdRumWeb;
      rumWeb.initRum(configuration);
    }
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
}

@JS()
@anonymous
class _JsUser {
  external String? get id;
  external String? get email;
  external String? get name;

  external factory _JsUser({
    String? id,
    String? email,
    String? name,
  });
}

@JS('setUser')
external void _jsSetUser(_JsUser newUser);
