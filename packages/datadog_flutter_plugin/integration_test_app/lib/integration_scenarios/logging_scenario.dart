// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

class LoggingScenario extends StatefulWidget {
  const LoggingScenario({Key? key}) : super(key: key);

  @override
  State<LoggingScenario> createState() => _LoggingScenarioState();
}

class _LoggingScenarioState extends State<LoggingScenario> {
  @override
  void initState() {
    super.initState();

    // Create a logger that will not send to Datadog
    var silentLogger = DatadogSdk.instance.logs!.createLogger(
      DatadogLoggerConfiguration(
        name: 'silent_logger',
        remoteSampleRate: 0,
      ),
    );
    silentLogger.info('Interesting logging information');

    var logger =
        DatadogSdk.instance.logs!.createLogger(DatadogLoggerConfiguration());
    logger.addTag('tag1', 'tag-value');
    logger.addTag('my-tag');

    logger.addAttribute('logger-attribute1', 'string value');
    logger.addAttribute('logger-attribute2', 1000);

    logger.debug('debug message', attributes: {'stringAttribute': 'string'});

    logger.removeTag('my-tag');
    logger.info('info message', attributes: {
      'nestedAttribute': {'internal': 'test', 'isValid': true}
    });
    logger.warn('warn message', attributes: {'doubleAttribute': 10.34});

    logger.removeAttribute('logger-attribute1');
    logger.removeTagWithKey('tag1');
    logger.error('error message', attributes: {'attribute': 'value'});

    try {
      throw Exception('This thing failed');
    } catch (e, st) {
      logger.error('Encountered an error',
          errorMessage: e.toString(), errorStackTrace: st);
    }

    final config = DatadogLoggerConfiguration(name: 'second_logger');
    final secondLogger = DatadogSdk.instance.logs!.createLogger(config);

    secondLogger.addAttribute('second-logger-attribute', 'second-value');
    secondLogger.info('message on second logger');

    final st = StackTrace.current;

    secondLogger.warn(
      'Warning: this error occurred',
      errorMessage: 'Error Message',
      errorStackTrace: st,
    );
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
