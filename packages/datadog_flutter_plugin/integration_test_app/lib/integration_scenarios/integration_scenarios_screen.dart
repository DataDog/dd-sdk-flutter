// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../auto_integration_scenarios/rum_auto_instrumentation_scenario.dart';
import 'kiosk_integration_scenario.dart';
import 'logging_scenario.dart';
import 'rum_manual_error_reporting_scenario.dart';
import 'rum_manual_instrumentation_scenario.dart';

class IntegrationScenariosScreen extends StatefulWidget {
  const IntegrationScenariosScreen({Key? key}) : super(key: key);

  @override
  State<IntegrationScenariosScreen> createState() =>
      _IntegrationScenariosScreenState();
}

typedef SimpleWidgetConstructor = Widget Function();

class ScenarioItem {
  final String label;
  final SimpleWidgetConstructor navItem;

  ScenarioItem({required this.label, required this.navItem});
}

class _IntegrationScenariosScreenState
    extends State<IntegrationScenariosScreen> {
  final items = <ScenarioItem>[
    ScenarioItem(label: 'Logging Scenario', navItem: LoggingScenario.new),
    ScenarioItem(
      label: 'Manual RUM Scenario',
      navItem: RumManualInstrumentationScenario.new,
    ),
    ScenarioItem(
      label: 'RUM Error Reporting Scenario',
      navItem: RumManualErrorReportingScenario.new,
    ),
    ScenarioItem(
      label: 'Auto RUM Scenario',
      navItem: RumAutoInstrumentationScenario.new,
    ),
    ScenarioItem(
      label: 'Kiosk RUM Scenario',
      navItem: KioskIntegrationScenario.new,
    )
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integration Scenarios'),
      ),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          var item = items[i];
          return ListTile(
            title: Text(item.label),
            trailing: const Icon(Icons.arrow_right_sharp),
            onTap: () {
              Navigator.push<void>(
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
