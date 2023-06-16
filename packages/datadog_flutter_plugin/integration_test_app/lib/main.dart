// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'auto_integration_scenarios/scenario_runner.dart' as auto_config_runners;
import 'integration_scenarios/integration_scenarios_screen.dart';
import 'integration_scenarios/scenario_runner.dart' as config_runners;

TestingConfiguration? testingConfiguration;

Future<void> runScenario({
  required String clientToken,
  required String? applicationId,
  required String? customEndpoint,
  TestingConfiguration? testingConfiguration,
}) async {
  var scenario = testingConfiguration?.scenario;
  switch (scenario) {
    case auto_config_runners.autoInstrumentationScenarioName:
      await auto_config_runners.runScenario(
          clientToken: clientToken,
          applicationId: applicationId,
          customEndpoint: customEndpoint,
          testingConfiguration: testingConfiguration);
      return;
    case config_runners.mappedInstrumentationScenarioName:
    case config_runners.mappedLoggingScenarioRunner:
      await config_runners.runScenario(
        clientToken: clientToken,
        applicationId: applicationId,
        customEndpoint: customEndpoint,
        testingConfiguration: testingConfiguration,
      );
      return;
  }

  // Default runner
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
    customEndpoint: customEndpoint,
    loggingConfiguration: LoggingConfiguration(
      sendNetworkInfo: true,
      printLogsToConsole: true,
    ),
    rumConfiguration: applicationId != null
        ? RumConfiguration(applicationId: applicationId)
        : null,
  );
  if (testingConfiguration?.additionalConfig != null) {
    configuration.additionalConfig
        .addAll(testingConfiguration!.additionalConfig);
  }

  await DatadogSdk.instance.initialize(configuration);
  DatadogSdk.instance.sdkVerbosity = Verbosity.verbose;

  runApp(const DatadogIntegrationTestApp());
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();

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

  await runScenario(
    clientToken: clientToken,
    applicationId: applicationId,
    customEndpoint: customEndpoint,
    testingConfiguration: testingConfiguration,
  );
}

/// -- Default Runner --

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
      home: const Column(
        children: [
          Expanded(child: IntegrationScenariosScreen()),
          SessionFooter(),
        ],
      ),
    );
  }
}

class SessionFooter extends StatefulWidget {
  const SessionFooter({super.key});

  @override
  State<SessionFooter> createState() => _SessionFooterState();
}

class _SessionFooterState extends State<SessionFooter> {
  String get currentSessionId => DatadogSdk.instance.rum?.sessionId ?? '<none>';

  @override
  void initState() {
    super.initState();

    DatadogSdk.instance.rum?.sessionStarted = (sessionId) {
      setState(() {});
    };

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final sessionFooterOverlay = OverlayEntry(builder: (context) {
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: IntrinsicHeight(
              child: Container(
                color: Colors.blueAccent,
                child: Center(
                  child: Text(
                    key: const Key('sessionId'),
                    'sessionId: $currentSessionId',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
            ),
          ),
        );
      });

      Overlay.of(context).insert(sessionFooterOverlay);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}
