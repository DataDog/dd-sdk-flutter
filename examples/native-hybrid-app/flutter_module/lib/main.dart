// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

import 'my_app.dart';

Future<void> _initializeDatadog() async {
  print('initializing datadog');
  DatadogSdk.instance.sdkVerbosity = CoreLoggerLevel.debug;

  final config = DatadogConfiguration(
      clientToken: '',
      env: 'prod',
      site: DatadogSite.us1,
      uploadFrequency: UploadFrequency.frequent,
      batchSize: BatchSize.small,
      loggingConfiguration: DatadogLoggingConfiguration(),
      rumConfiguration: DatadogRumConfiguration(
        applicationId: '',
        traceSampleRate: 100.0,
      ));
  await DatadogSdk.instance.initialize(config, TrackingConsent.granted);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeDatadog();

  // final config = DatadogAttachConfiguration(
  //   detectLongTasks: true,
  //   reportFlutterPerformance: true,
  // )..enableHttpTracking();

  // await DatadogSdk.instance.attachToExisting(config);

  runApp(MyApp());
}
