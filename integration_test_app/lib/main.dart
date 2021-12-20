import 'dart:io';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(mergeWith: Platform.environment);

  final configuration = DdSdkConfiguration(
    clientToken: dotenv.get('DD_CLIENT_TOKEN', fallback: ''),
    env: dotenv.get('DD_ENV', fallback: ''),
    applicationId: dotenv.get('DD_APPLICATION_ID', fallback: ''),
    trackingConsent: 'granted',
  );

  if (testingConfiguration != null) {
    // TODO: batch size and upload frequency
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
      home: const ScenarioPage(title: 'Datadog Integration Tests'),
    );
  }
}

class ScenarioPage extends StatefulWidget {
  const ScenarioPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<ScenarioPage> createState() => _ScenarioPageState();
}

class _ScenarioPageState extends State<ScenarioPage> {
  final items = <NavItem>[
    NavItem(label: 'Logging Scenario', navItem: LoggingScenario.new)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          var item = items[i];
          return ListTile(
            title: Text(item.label),
            trailing: const Icon(Icons.arrow_right_sharp),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => item.navItem(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
