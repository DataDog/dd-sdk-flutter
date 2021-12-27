import 'dart:io';

import 'package:datadog_integration_test_app/integration_scenarios/integration_scenarios_screen.dart';
import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'integration_scenarios/logging_scenario.dart';

typedef SimpleWidgetConstructor = Widget Function();

class TestingConfiguration {
  String? customEndpoint;
  String? clientToken;
  String? applicationId;

  TestingConfiguration({
    this.customEndpoint,
    this.clientToken,
    this.applicationId,
  });
}

TestingConfiguration? testingConfiguration;

class NavItem {
  final String label;
  final SimpleWidgetConstructor navItem;

  NavItem({required this.label, required this.navItem});
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(mergeWith: Platform.environment);

  final configuration = DdSdkConfiguration(
    clientToken: dotenv.get('DD_CLIENT_TOKEN', fallback: ''),
    env: dotenv.get('DD_ENV', fallback: ''),
    applicationId: dotenv.get('DD_APPLICATION_ID', fallback: ''),
    trackingConsent: TrackingConsent.granted,
    uploadFrequency: UploadFrequency.frequent,
    batchSize: BatchSize.small,
  );

  if (testingConfiguration != null) {
    if (testingConfiguration!.customEndpoint != null) {
      configuration.customEndpoint = testingConfiguration!.customEndpoint;
      if (testingConfiguration!.clientToken != null) {
        configuration.clientToken = testingConfiguration!.clientToken!;
      }
      if (testingConfiguration!.applicationId != null) {
        configuration.applicationId = testingConfiguration!.applicationId;
      }
    }
  }

  final ddsdk = DatadogSdk();
  await ddsdk.initialize(configuration);

  runApp(const DatadogIntegrationTestApp());
}

class DatadogIntegrationTestApp extends StatelessWidget {
  const DatadogIntegrationTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const IntegrationScenariosScreen());
  }
}
