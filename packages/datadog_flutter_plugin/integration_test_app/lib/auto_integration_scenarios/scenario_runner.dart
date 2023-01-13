// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'rum_auto_instrumentation_scenario.dart';
import 'scenario_config.dart';

const autoInstrumentationScenarioName = 'auto_instrumentation_scenario';

Future<void> runScenario({
  required String clientToken,
  required String? applicationId,
  required String? customEndpoint,
  TestingConfiguration? testingConfiguration,
}) async {
  final firstPartyHosts = ['datadoghq.com'];
  if (testingConfiguration != null) {
    firstPartyHosts.addAll(testingConfiguration.firstPartyHosts);
    firstPartyHosts
        .addAll(RumAutoInstrumentationScenarioConfig.instance.firstPartyHosts);
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
    telemetrySampleRate: 100,
    loggingConfiguration: LoggingConfiguration(
      sendNetworkInfo: true,
      printLogsToConsole: true,
    ),
    rumConfiguration: applicationId != null
        ? RumConfiguration(
            applicationId: applicationId,
            reportFlutterPerformance: true,
            customEndpoint: customEndpoint,
          )
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
    final navObserver =
        DatadogNavigationObserver(datadogSdk: DatadogSdk.instance);
    return DatadogNavigationObserverProvider(
      navObserver: navObserver,
      child: RumUserActionDetector(
        rum: DatadogSdk.instance.rum,
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
      ),
    );
  }
}
