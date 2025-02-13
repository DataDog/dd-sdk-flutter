// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:isolate';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum LogLevel { debug, info, notice, warn, error }

class LoggingScreen extends StatefulWidget {
  const LoggingScreen({super.key});

  @override
  State<LoggingScreen> createState() => _LoggingScreenState();
}

class _LoggingScreenState extends State<LoggingScreen> {
  DatadogLogger? logger;

  @override
  void initState() {
    logger =
        DatadogSdk.instance.logs?.createLogger(DatadogLoggerConfiguration());
    super.initState();
  }

  Future<void> _sendPressed(LogLevel logLevel) async {
    final message = '$logLevel Message';
    switch (logLevel) {
      case LogLevel.debug:
        logger?.debug(message);
        break;
      case LogLevel.info:
        logger?.info(message);
        break;
      case LogLevel.notice:
        logger?.info(message);
        break;
      case LogLevel.warn:
        logger?.warn(message);
        break;
      case LogLevel.error:
        logger?.error(message);
        break;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Sent $message')));
  }

  void _sendErrorWithExceptionLog() {
    const message = 'Error With Exception Log';
    try {
      throw Exception('We threw an exception!');
    } catch (e, st) {
      logger?.error(
        message,
        errorMessage: e.toString(),
        errorStackTrace: st,
      );
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sent $message')));
  }

  void _sendFromBackgroundIsolate() {
    final rootIsolateToken = ServicesBinding.rootIsolateToken;

    Isolate.spawn(sendBackgroundLogs, rootIsolateToken!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logging Tests'),
      ),
      body: Container(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () => _sendPressed(LogLevel.debug),
              child: const Text('Debug Log'),
            ),
            ElevatedButton(
              onPressed: () => _sendPressed(LogLevel.info),
              child: const Text('Info Log'),
            ),
            ElevatedButton(
              onPressed: () => _sendPressed(LogLevel.notice),
              child: const Text('Notice Log'),
            ),
            ElevatedButton(
              onPressed: () => _sendPressed(LogLevel.warn),
              child: const Text('Warn Log'),
            ),
            ElevatedButton(
              onPressed: () => _sendPressed(LogLevel.error),
              child: const Text('Error Log'),
            ),
            ElevatedButton(
              onPressed: () => _sendErrorWithExceptionLog(),
              child: const Text('Error With Exception Log'),
            ),
            if (!kIsWeb)
              ElevatedButton(
                onPressed: () => _sendFromBackgroundIsolate(),
                child: const Text('Send From Background Isolate'),
              ),
          ],
        ),
      ),
    );
  }
}

void sendBackgroundLogs(RootIsolateToken rootIsolateToken) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

  await DatadogSdk.instance.attachToExisting(DatadogAttachConfiguration(
    detectLongTasks: true,
  ));

  final logger = DatadogSdk.instance.logs?.createLogger(
    DatadogLoggerConfiguration(),
  );

  logger?.debug('Testing background isolate logging');
}
