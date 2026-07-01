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
    event.view.url = 'ThirdView';
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
  if (event.error.fingerprint == 'custom-fingerprint') {
    event.error.fingerprint = 'mapped fingerprint';
  }

  return event;
}

RumLongTaskEvent? mapRumLongTaskEvent(RumLongTaskEvent event) {
  // Drop anything less than 200 ms
  if (event.longTask.duration <
      const Duration(milliseconds: 200).inNanoseconds) {
    return null;
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

  final configuration = DatadogConfiguration(
    clientToken: clientToken,
    env: dotenv.get('DD_ENV', fallback: ''),
    service: 'com.datadoghq.flutter.integration',
    version: '1.2.3+555',
    flavor: 'integration',
    site: DatadogSite.us1,
    uploadFrequency: UploadFrequency.frequent,
    batchSize: BatchSize.small,
    nativeCrashReportEnabled: true,
    firstPartyHosts: firstPartyHosts,
    loggingConfiguration: DatadogLoggingConfiguration(
      eventMapper: _mapLogEvent,
      customEndpoint: customEndpoint,
    ),
    rumConfiguration: applicationId != null
        ? DatadogRumConfiguration(
            applicationId: applicationId,
            reportFlutterPerformance: true,
            customEndpoint: customEndpoint,
            telemetrySampleRate: 100,
            additionalConfig: testingConfiguration?.additionalConfig ?? {},
          )
        : null,
  )..additionalConfig['_dd.needsClearTextHttp'] = true;
  if (testingConfiguration?.additionalConfig != null) {
    configuration.additionalConfig
        .addAll(testingConfiguration!.additionalConfig);
  }

  if (testingConfiguration?.scenario == mappedInstrumentationScenarioName) {
    // Add mapping to rum configuration
    configuration.rumConfiguration?.viewEventMapper = mapRumViewEvent;
    configuration.rumConfiguration?.actionEventMapper = mapRumActionEvent;
    configuration.rumConfiguration?.resourceEventMapper = mapRumResourceEvent;
    configuration.rumConfiguration?.errorEventMapper = mapRumErrorEvent;
    configuration.rumConfiguration?.longTaskEventMapper = mapRumLongTaskEvent;
  }

  await DatadogSdk.runApp(configuration, TrackingConsent.granted, () async {
    runApp(const DatadogIntegrationTestApp());
  });
}

LogEvent? _mapLogEvent(LogEvent event) {
  event.attributes.remove('logger-attribute2');

  if (event.logger.name == 'second_logger') {
    if (event.status == LogStatus.info) {
      return null;
    }
    event.error?.fingerprint = 'mapped print';
  }

  event.message = event.message.replaceAll('message', 'xxxxxxxx');

  return event;
}

final routeObserver = RouteObserver<ModalRoute<dynamic>>();

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
