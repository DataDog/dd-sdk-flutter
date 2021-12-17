// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.
import 'dart:io';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'example_app.dart';

class TestingConfiguration {
  String? customEndpoint;
  String? clientToken;
  String? applicationId;

  TestingConfiguration({
    this.customEndpoint,
    this.clientToken,
    this.applicationId,
  });
}

TestingConfiguration? testingConfiguration;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(mergeWith: Platform.environment);

  final configuration = DdSdkConfiguration(
    clientToken: dotenv.get('DD_CLIENT_TOKEN', fallback: ''),
    env: dotenv.get('DD_ENV', fallback: ''),
    applicationId: dotenv.get('DD_APPLICATION_ID', fallback: ''),
    trackingConsent: 'granted',
  );

  if (testingConfiguration != null) {
    // TODO: batch size and upload frequency
    if (testingConfiguration!.customEndpoint != null) {
      configuration.customEndpoint = testingConfiguration!.customEndpoint;
      if (testingConfiguration!.clientToken != null) {
        configuration.clientToken = testingConfiguration!.clientToken!;
      }
      if (testingConfiguration!.applicationId != null) {
        configuration.applicationId = testingConfiguration!.applicationId;
      }
    }
  }

  final ddsdk = DatadogSdk();
  await ddsdk.initialize(configuration);

  runApp(const ExampleApp());
}
