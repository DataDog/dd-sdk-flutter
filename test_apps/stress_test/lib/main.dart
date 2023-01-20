// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/test_select_screen.dart';

void main() async {
  DatadogSdk.instance.sdkVerbosity = Verbosity.verbose;

  await dotenv.load();
  var addMappers = true;

  var applicationId = dotenv.maybeGet('DD_APPLICATION_ID');

  final ddconfig = DdSdkConfiguration(
    clientToken: dotenv.get('DD_CLIENT_TOKEN', fallback: ''),
    env: dotenv.get('DD_ENV', fallback: ''),
    site: DatadogSite.us1,
    trackingConsent: TrackingConsent.granted,
    batchSize: BatchSize.large,
    uploadFrequency: UploadFrequency.rare,
    nativeCrashReportEnabled: true,
    loggingConfiguration: LoggingConfiguration(
      sendNetworkInfo: true,
      printLogsToConsole: true,
    ),
    rumConfiguration: applicationId != null
        ? RumConfiguration(
            applicationId: applicationId,
            reportFlutterPerformance: true,
            detectLongTasks: true,
          )
        : null,
  )..additionalConfig[DatadogConfigKey.trackMapperPerformance] = true;

  if (addMappers) {
    ddconfig.logEventMapper = (event) => event;
    ddconfig.rumConfiguration?.rumViewEventMapper = (event) => event;
    ddconfig.rumConfiguration?.rumActionEventMapper = (event) => event;
    ddconfig.rumConfiguration?.rumResourceEventMapper = (event) => event;
    ddconfig.rumConfiguration?.rumErrorEventMapper = (event) => event;
    ddconfig.rumConfiguration?.rumLongTaskEventMapper = (event) => event;
  }

  await DatadogSdk.runApp(
    ddconfig,
    () {
      return runApp(const MyApp());
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final navigationObserver =
        DatadogNavigationObserver(datadogSdk: DatadogSdk.instance);
    return DatadogNavigationObserverProvider(
      navObserver: navigationObserver,
      child: MaterialApp(
        title: 'Datadog Stress Test',
        navigatorObservers: [navigationObserver],
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const TestSelectScreen(),
      ),
    );
  }
}
