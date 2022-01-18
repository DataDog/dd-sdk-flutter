// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.
import 'dart:async';
import 'dart:io';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:datadog_sdk/rum/ddrum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'example_app.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(mergeWith: Platform.environment);

    final configuration = DdSdkConfiguration(
      clientToken: dotenv.get('DD_CLIENT_TOKEN', fallback: ''),
      env: dotenv.get('DD_ENV', fallback: ''),
      applicationId: dotenv.get('DD_APPLICATION_ID', fallback: ''),
      trackingConsent: TrackingConsent.granted,
    );

    final ddsdk = DatadogSdk.instance;
    await ddsdk.initialize(configuration);

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      ddsdk.ddRum?.handleFlutterError(details);
    };

    runApp(const ExampleApp());
  }, (e, s) {
    DatadogSdk.instance.ddRum
        ?.addErrorInfo(e.toString(), RumErrorSource.source, stackTrace: s);
  });
}
