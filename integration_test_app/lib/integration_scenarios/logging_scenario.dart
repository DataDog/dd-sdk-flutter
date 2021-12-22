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
    if (logger != null) {
      logger.addTag('tag1', 'tag-value');
      logger.addTag('my-tag');

      logger.addAttribute('logger-attribute1', 'string value');
      logger.addAttribute('logger-attribute2', 1000);

      logger.debug('debug message', {'stringAttribute': 'string'});

      logger.removeTag('my-tag');
      logger.info('info message', {
        'nestedAttribute': {'internal': 'test', 'isValid': true}
      });
      logger.warn('warn message', {'doubleAttribute': 10.34});

      logger.removeAttribute('logger-attribute1');
      logger.removeTagWithKey('tag1');
      logger.error('error message', {'attribute': 'value'});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logging Scenario'),
      ),
      body: Container(),
    );
  }
}
