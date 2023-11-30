// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';

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
    batchSize: BatchSize.small,
    uploadFrequency: UploadFrequency.frequent,
    loggingConfiguration: DatadogLoggingConfiguration(),
    rumConfiguration: applicationId != null
        ? DatadogRumConfiguration(
            applicationId: applicationId,
            detectLongTasks: true,
            reportFlutterPerformance: true,
            //customEndpoint: 'http://192.168.7.51:8000/rum',
          )
        : null,
  )..enableSessionReplay(
      DatadogSessionReplayConfiguration(
        replaySampleRate: 1.0,
        //customEndpoint: 'http://192.168.7.51:8000/replay',
      ),
    );

  final ddsdk = DatadogSdk.instance;
  ddsdk.sdkVerbosity = CoreLoggerLevel.debug;
  await DatadogSdk.runApp(configuration, TrackingConsent.granted, () async {
    return runApp(const MyApp());
  });

  runApp(const MyApp());
}
