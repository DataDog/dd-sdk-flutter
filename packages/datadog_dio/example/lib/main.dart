// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import 'dart:io';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_dio/datadog_dio.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/instrumentation_scenario.dart';

// import 'scenario_config.dart';
// import 'scenario_select_screen.dart';

// This file sets up a different application for testing auto instrumentation
// Using the widgets in this library by themselves won't send any RUM events
// but, by utilizing this entry point instead, we can test that
// auto-instrumentation added to an existing app gives us the expected results.
TestingConfiguration? testingConfiguration;

Future<void> main() async {
  final merge = kIsWeb ? <String, String>{} : Platform.environment;
  await dotenv.load(mergeWith: merge);

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

  DatadogSdk.instance.sdkVerbosity = CoreLoggerLevel.debug;

  final configuration = DatadogConfiguration(
    clientToken: clientToken,
    env: dotenv.get('DD_ENV', fallback: ''),
    site: DatadogSite.us1,
    uploadFrequency: UploadFrequency.frequent,
    batchSize: BatchSize.small,
    nativeCrashReportEnabled: true,
    firstPartyHosts: firstPartyHosts,
    loggingConfiguration: DatadogLoggingConfiguration(
      customEndpoint: customEndpoint,
    ),
    rumConfiguration: applicationId != null
        ? DatadogRumConfiguration(
            detectLongTasks: false,
            applicationId: applicationId,
            traceSampleRate: 100,
            customEndpoint: customEndpoint,
            trackResourceHeaders: ResourceHeadersExtractor(
              captureHeaders: [
                'accept-ranges',
                'content-disposition',
                'server',
                'user-agent',
                'via',
                'x-cache-hits',
                'x-served-by',
                'x-datadog-trace-id',
                'x-datadog-parent-id',
                'x-datadog-origin',
                'traceparent',
              ],
            ),
          )
        : null,
  );
  if (testingConfiguration != null) {
    // Add clear text if we're running an actual test.
    configuration.additionalConfig['_dd.needsClearTextHttp'] = true;
  }

  await DatadogSdk.runApp(configuration, TrackingConsent.granted, () async {
    final dio = Dio(BaseOptions(
      validateStatus: (status) => status != null && status < 300,
    ))
      ..addDatadogInterceptor(
        DatadogSdk.instance,
      );
    // User for testing baggage headers
    DatadogSdk.instance.setUserInfo(id: 'integration_test_user');
    DatadogSdk.instance.setAccountInfo(id: 'integration_test_account');

    runApp(DatadogAutoIntegrationTestApp(dio: dio));
  });
}

class DatadogAutoIntegrationTestApp extends StatelessWidget {
  final Dio dio;

  const DatadogAutoIntegrationTestApp({super.key, required this.dio});

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
        home: InstrumentationScenario(dio: dio),
      ),
    );
  }
}
