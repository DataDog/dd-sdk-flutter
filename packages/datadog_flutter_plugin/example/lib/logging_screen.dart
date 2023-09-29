// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum LogLevel { debug, info, notice, warn, error }

class LoggingScreen extends StatefulWidget {
  const LoggingScreen({Key? key}) : super(key: key);

  @override
  State<LoggingScreen> createState() => _LoggingScreenState();
}

class _LoggingScreenState extends State<LoggingScreen> {
  var _disableSendingLogs = false;
  var _selectedLevel = LogLevel.debug;
  String? _message;

  late DatadogLogger? logger;

  @override
  void initState() {
    logger =
        DatadogSdk.instance.logs?.createLogger(DatadogLoggerConfiguration());
    super.initState();
  }

  void _logLevelChanged(LogLevel? value) {
    setState(() {
      _selectedLevel = value ?? LogLevel.debug;
    });
  }

  Future<void> _sendPressed(int count) async {
    setState(() {
      _disableSendingLogs = true;
    });
    final message = _message ?? 'Default Message';
    for (var i = 0; i < count; ++i) {
      switch (_selectedLevel) {
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
    }
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _disableSendingLogs = false;
    });
  }

  void _sendErrorLog() {
    setState(() {
      _disableSendingLogs = true;
    });
    try {
      throw Exception('We threw an exception!');
    } catch (e, st) {
      logger?.error(
        'Error you asked for',
        errorMessage: e.toString(),
        errorStackTrace: st,
      );
    }
    setState(() {
      _disableSendingLogs = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logging Example'),
      ),
      body: Container(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Single log',
              style: theme.textTheme.titleLarge,
            ),
            _buildField(
              text: 'LEVEL',
              child: CupertinoSlidingSegmentedControl<LogLevel>(
                onValueChanged: _logLevelChanged,
                groupValue: _selectedLevel,
                children: {
                  for (var value in LogLevel.values)
                    value: _buildSegment(
                      value
                          .toString()
                          .replaceFirst('LogLevel.', '')
                          .toUpperCase(),
                    )
                },
              ),
            ),
            _buildField(
              child: TextField(
                onChanged: (value) => _message = value,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _disableSendingLogs ? null : () => _sendPressed(1),
                    child: const Text('Send once'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _disableSendingLogs ? null : () => _sendPressed(10),
                    child: const Text('Send 10x'),
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _disableSendingLogs ? null : () => _sendErrorLog(),
              child: const Text('Send Log With Exception'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({String? text, required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text != null)
            Text(
              text,
              style: theme.textTheme.titleSmall,
            ),
          Container(padding: const EdgeInsets.all(4), child: child),
        ],
      ),
    );
  }

  Widget _buildSegment(String title) {
    return Container(
      padding: const EdgeInsets.all(5),
      child: Text(title),
    );
  }
}
