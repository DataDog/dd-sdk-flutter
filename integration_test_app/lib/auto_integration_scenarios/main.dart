import 'dart:io';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../helpers.dart';
import 'rum_auto_instrumentation_scenario.dart';
import 'scenario_config.dart';

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
      if (testingConfiguration!.clientToken != null) {
        clientToken = testingConfiguration!.clientToken!;
      }
      if (testingConfiguration!.applicationId != null) {
        applicationId = testingConfiguration!.applicationId;
      }
    }
  }

  final firstPartyHosts = ['datadoghq.com'];
  if (testingConfiguration != null) {
    firstPartyHosts.addAll(testingConfiguration!.firstPartyHosts);
    firstPartyHosts
        .addAll(RumAutoInstrumentationScenarioConfig.instance.firstPartyHosts);
  }

  final configuration = DdSdkConfiguration(
    clientToken: clientToken,
    env: dotenv.get('DD_ENV', fallback: ''),
    trackingConsent: TrackingConsent.granted,
    uploadFrequency: UploadFrequency.frequent,
    batchSize: BatchSize.small,
    nativeCrashReportEnabled: true,
    trackHttpClient: true,
    firstPartyHosts: firstPartyHosts,
    customEndpoint: customEndpoint,
    loggingConfiguration: LoggingConfiguration(
      sendNetworkInfo: true,
      printLogsToConsole: true,
    ),
    tracingConfiguration: TracingConfiguration(
      sendNetworkInfo: true,
    ),
    rumConfiguration: applicationId != null
        ? RumConfiguration(applicationId: applicationId)
        : null,
  );

  await DatadogSdk.runApp(configuration, () async {
    runApp(const DatadogAutoIntegrationTestApp());
  });
}

class DatadogAutoIntegrationTestApp extends StatelessWidget {
  const DatadogAutoIntegrationTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      navigatorObservers: [DatadogNavigationObserver()],
      home: const RumAutoInstrumentationScenario(),
    );
  }
}
