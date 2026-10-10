// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'example_app.dart';

void main() async {
  await dotenv.load();

  var applicationId = dotenv.maybeGet('DD_APPLICATION_ID');

  final configuration = DatadogConfiguration(
    clientToken: dotenv.get('DD_CLIENT_TOKEN', fallback: ''),
    env: dotenv.get('DD_ENV', fallback: ''),
    service: 'com.datadoghq.example.flutter',
    version: '1.2.3',
    site: DatadogSite.us1,
    nativeCrashReportEnabled: true,
    loggingConfiguration: DatadogLoggingConfiguration(),
    rumConfiguration: applicationId != null
        ? DatadogRumConfiguration(
            sessionSamplingRate: 100.0,
            applicationId: applicationId,
            detectLongTasks: true,
            reportFlutterPerformance: true,
            actionEventMapper: (event) {
              if (event.action.target?.name == 'Test Action') {
                event.action.target?.name = 'Replaced';
              }
              return event;
            },
          )
        : null,
  );

  final ddsdk = DatadogSdk.instance;
  ddsdk.sdkVerbosity = CoreLoggerLevel.debug;
  DatadogSdk.runApp(configuration, TrackingConsent.granted, () async {
    return runApp(const ExampleApp());
  });
}
