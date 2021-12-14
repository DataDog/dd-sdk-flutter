import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter/material.dart';

class LoggingScenario extends StatefulWidget {
  const LoggingScenario({Key? key}) : super(key: key);

  @override
  _LoggingScenarioState createState() => _LoggingScenarioState();
}

class _LoggingScenarioState extends State<LoggingScenario> {
  @override
  void initState() {
    super.initState();

    var logger = DatadogSdk().ddLogs;
    logger.debug('debug message', {'attribute': 'value'});
    logger.info('info message', {'attribute': 'value'});
    logger.warn('warn message', {'attribute': 'value'});
    logger.error('error message', {'attribute': 'value'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Looging Scenario'),
      ),
      body: Container(),
    );
  }
}
