import 'dart:io';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'helpers.dart';
import 'integration_scenarios/integration_scenarios_screen.dart';

TestingConfiguration? testingConfiguration;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  final configuration = DdSdkConfiguration(
    clientToken: clientToken,
    env: dotenv.get('DD_ENV', fallback: ''),
    trackingConsent: TrackingConsent.granted,
    uploadFrequency: UploadFrequency.frequent,
    batchSize: BatchSize.small,
    nativeCrashReportEnabled: true,
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

  await DatadogSdk.instance.initialize(configuration);

  runApp(const DatadogIntegrationTestApp());
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
