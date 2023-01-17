// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'integration_scenarios_screen.dart';

const mappedLoggingScenarioRunner = 'mapped_logging_scenario';

Future<void> runScenario({
  required String clientToken,
  required String? applicationId,
  required String? customEndpoint,
  TestingConfiguration? testingConfiguration,
}) async {
  final firstPartyHosts = ['datadoghq.com'];
  if (testingConfiguration != null) {
    firstPartyHosts.addAll(testingConfiguration.firstPartyHosts);
  }

  final configuration = DdSdkConfiguration(
    clientToken: clientToken,
    env: dotenv.get('DD_ENV', fallback: ''),
    serviceName: 'com.datadoghq.flutter.integration',
    version: '1.2.3+555',
    flavor: 'integration',
    site: DatadogSite.us1,
    trackingConsent: TrackingConsent.granted,
    uploadFrequency: UploadFrequency.frequent,
    batchSize: BatchSize.small,
    nativeCrashReportEnabled: true,
    firstPartyHosts: firstPartyHosts,
    customLogsEndpoint: customEndpoint,
    telemetrySampleRate: 100,
    logEventMapper: (event) => _mapLogEvent(event),
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
    runApp(const DatadogIntegrationTestApp());
  });
}

LogEvent? _mapLogEvent(LogEvent event) {
  event.attributes.remove('logger-attribute2');

  if (event.logger.name == 'second_logger' && event.status == LogStatus.info) {
    return null;
  }

  event.message = event.message.replaceAll('message', 'xxxxxxxx');

  return event;
}

final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

class DatadogIntegrationTestApp extends StatelessWidget {
  const DatadogIntegrationTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      navigatorObservers: [routeObserver],
      home: const IntegrationScenariosScreen(),
    );
  }
}
