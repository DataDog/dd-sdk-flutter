// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_tracking_http_client/datadog_tracking_http_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';

void main() async {
  await dotenv.load();

  WidgetsFlutterBinding.ensureInitialized();

  DatadogSdk.instance.sdkVerbosity = Verbosity.verbose;
  final datadogConfig = DdSdkConfiguration(
    clientToken: dotenv.get('DD_CLIENT_TOKEN', fallback: ''),
    env: dotenv.get('DD_ENV', fallback: ''),
    trackingConsent: TrackingConsent.granted,
    site: DatadogSite.us1,
    loggingConfiguration: LoggingConfiguration(
      sendLogsToDatadog: true,
      printLogsToConsole: true,
    ),
    rumConfiguration: RumConfiguration(
      applicationId: dotenv.get('DD_APPLICATION_ID', fallback: ''),
    ),
  )..enableHttpTracking();

  // runUsingRunApp(datadogConfig);
  runUsingAlternativeInit(datadogConfig);
}

Future<void> runUsingAlternativeInit(DdSdkConfiguration datadogConfig) async {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    DatadogSdk.instance.rum?.handleFlutterError(details);
    originalOnError?.call(details);
  };

  final platformOriginalOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (e, st) {
    DatadogSdk.instance.rum?.addErrorInfo(
      e.toString(),
      RumErrorSource.source,
      stackTrace: st,
    );
    return platformOriginalOnError?.call(e, st) ?? false;
  };

  await DatadogSdk.instance.initialize(datadogConfig);
  runApp(MyApp());
}

Future<void> runUsingRunApp(DdSdkConfiguration datadogConfig) async {
  await DatadogSdk.runApp(datadogConfig, () {
    DatadogSdk.instance.sdkVerbosity = Verbosity.verbose;
    runApp(MyApp());
  });
}
