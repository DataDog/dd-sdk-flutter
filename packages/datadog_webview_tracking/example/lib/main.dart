// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:async';
import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';

String? customEndpoint;

Future<void> main() async {
  await dotenv.load(mergeWith: Platform.environment);

  var clientToken = dotenv.get('DD_CLIENT_TOKEN', fallback: '');
  var applicationId = dotenv.maybeGet('DD_APPLICATION_ID');
  customEndpoint ??= dotenv.maybeGet('DD_CUSTOM_ENDPOINT');

  DatadogSdk.instance.sdkVerbosity = CoreLoggerLevel.debug;

  final configuration = DatadogConfiguration(
    clientToken: clientToken,
    env: dotenv.get('DD_ENV', fallback: ''),
    site: DatadogSite.us1,
    uploadFrequency: UploadFrequency.frequent,
    batchSize: BatchSize.small,
    nativeCrashReportEnabled: true,
    firstPartyHosts: [],
    loggingConfiguration: DatadogLoggingConfiguration(
      customEndpoint: customEndpoint,
    ),
    rumConfiguration: applicationId != null
        ? DatadogRumConfiguration(
            detectLongTasks: false,
            applicationId: applicationId,
            traceSampleRate: 100,
            customEndpoint: customEndpoint,
          )
        : null,
  );
  // This is only needed for interation testing, as the mock server doesn't support https
  if (customEndpoint != null) {
    configuration.additionalConfig['_dd.needsClearTextHttp'] = true;
  }

  await DatadogSdk.runApp(configuration, TrackingConsent.granted, () async {
    runApp(const MyApp());
  });
}
