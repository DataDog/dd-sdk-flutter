// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'integration_scenarios_screen.dart';

const mappedLoggingScenarioRunner = 'mapped_logging_scenario';
const mappedInstrumentationScenarioName =
    'mapped_auto_instrumentation_scenario';

RumViewEvent mapRumViewEvent(RumViewEvent event) {
  if (event.view.name == 'ThirdManualRumView') {
    event.view.name = 'ThirdView';
  }

  return event;
}

RumActionEvent? mapRumActionEvent(RumActionEvent event) {
  var actionTarget = event.action.target;
  if (actionTarget != null) {
    if (actionTarget.name.contains('Next Screen') ||
        actionTarget.name == 'User Scrolling') {
      return null;
    } else if (actionTarget.name == 'Tapped Download') {
      event.action.target?.name = 'Download';
    }
  }

  return event;
}

RumResourceEvent? mapRumResourceEvent(RumResourceEvent event) {
  event.resource.url = event.resource.url.replaceAll('fake_url', 'my_url');

  return event;
}

RumErrorEvent? mapRumErrorEvent(RumErrorEvent event) {
  if (event.error.resource != null) {
    event.error.resource?.url =
        event.error.resource!.url.replaceAll('fake_url', 'my_url');
  }

  return event;
}

RumLongTaskEvent? mapRumLongTaskEvent(RumLongTaskEvent event) {
  // Drop anything less than 200 ms
  if (event.longTask.duration <
      const Duration(milliseconds: 200).inNanoseconds) {
    return null;
  }

  if (event.view.name == 'ThirdManualRumView') {
    event.view.name = 'ThirdView';
  }

  return event;
}

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

  if (testingConfiguration?.scenario == mappedInstrumentationScenarioName) {
    // Add mapping to rum configuration
    configuration.rumConfiguration?.rumViewEventMapper = mapRumViewEvent;
    configuration.rumConfiguration?.rumActionEventMapper = mapRumActionEvent;
    configuration.rumConfiguration?.rumResourceEventMapper =
        mapRumResourceEvent;
    configuration.rumConfiguration?.rumErrorEventMapper = mapRumErrorEvent;
    configuration.rumConfiguration?.rumLongTaskEventMapper =
        mapRumLongTaskEvent;
  }

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
