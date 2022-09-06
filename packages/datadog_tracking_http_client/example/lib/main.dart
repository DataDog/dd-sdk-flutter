// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_tracking_http_client/datadog_tracking_http_client.dart';
import 'package:datadog_tracking_http_client_example/rum_auto_instrumentation_scenario.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// This file sets up a different application for testing auto instrumentation
// Using the widgets in this library by themselves won't send any RUM events
// but, by utilizing this entry point instead, we can test that
// auto-instrumentation added to an existing app gives us the expected results.
TestingConfiguration? testingConfiguration;

Future<void> main() async {
  await dotenv.load(mergeWith: Platform.environment);

  var clientToken = dotenv.get('DD_CLIENT_TOKEN', fallback: '');
  var applicationId = dotenv.maybeGet('DD_APPLICATION_ID');
  String? customEndpoint = dotenv.maybeGet('DD_CUSTOM_ENDPOINT');

  if (testingConfiguration != null) {
    if (testingConfiguration!.customEndpoint != null) {
      customEndpoint = testingConfiguration!.customEndpoint;
    }
    if (testingConfiguration!.clientToken != null) {
      clientToken = testingConfiguration!.clientToken!;
    }
    if (testingConfiguration!.applicationId != null) {
      applicationId = testingConfiguration!.applicationId;
    }
  }

  final firstPartyHosts = ['datadoghq.com'];
  if (testingConfiguration != null) {
    firstPartyHosts.addAll(testingConfiguration!.firstPartyHosts);
  }

  final configuration = DdSdkConfiguration(
    clientToken: clientToken,
    env: dotenv.get('DD_ENV', fallback: ''),
    site: DatadogSite.us1,
    trackingConsent: TrackingConsent.granted,
    uploadFrequency: UploadFrequency.frequent,
    batchSize: BatchSize.small,
    nativeCrashReportEnabled: true,
    firstPartyHosts: firstPartyHosts,
    customLogsEndpoint: customEndpoint,
    loggingConfiguration: LoggingConfiguration(
      sendNetworkInfo: true,
      printLogsToConsole: true,
    ),
    rumConfiguration: applicationId != null
        ? RumConfiguration(
            applicationId: applicationId,
            tracingSamplingRate: 100,
            customEndpoint: customEndpoint,
          )
        : null,
  )..enableHttpTracking();

  await DatadogSdk.runApp(configuration, () async {
    runApp(const DatadogAutoIntegrationTestApp());
  });
}

class DatadogAutoIntegrationTestApp extends StatelessWidget {
  const DatadogAutoIntegrationTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final navObserver =
        DatadogNavigationObserver(datadogSdk: DatadogSdk.instance);
    return DatadogNavigationObserverProvider(
      navObserver: navObserver,
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        navigatorObservers: [
          navObserver,
        ],
        home: const RumAutoInstrumentationScenario(),
      ),
    );
  }
}
