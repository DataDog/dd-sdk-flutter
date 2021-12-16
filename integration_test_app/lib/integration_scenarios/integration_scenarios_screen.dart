import 'package:flutter/material.dart';

import 'logging_scenario.dart';

class IntegrationScenariosScreen extends StatefulWidget {
  const IntegrationScenariosScreen({Key? key}) : super(key: key);

  @override
  _IntegrationScenariosScreenState createState() =>
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
