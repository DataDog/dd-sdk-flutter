// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

class TracingScreen extends StatefulWidget {
  const TracingScreen({Key? key}) : super(key: key);

  @override
  _TracingScreenState createState() => _TracingScreenState();
}

class _TracingScreenState extends State<TracingScreen> {
  var _sendErrorSpan = false;
  var _performingOperation = false;
  var _operationName = '';
  var _resourceName = '';
  var _rootOperationName = '';

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracing'),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _singleSpan(context, theme),
              _complexSpans(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _singleSpan(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Single span',
            style: theme.textTheme.headline5,
          ),
          Row(
            children: [
              const Text('Is Error:'),
              Switch(
                value: _sendErrorSpan,
                onChanged: _performingOperation
                    ? null
                    : (value) {
                        setState(() {
                          _sendErrorSpan = value;
                        });
                      },
              ),
            ],
          ),
          TextField(
            onChanged: (value) => _operationName = value,
            enabled: !_performingOperation,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Operation Name',
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          TextField(
            onChanged: (value) => _resourceName = value,
            enabled: !_performingOperation,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), labelText: 'Resource Name'),
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  child: const Text('Send'),
                  onPressed: _performingOperation ? null : _onSendSingleSpan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _complexSpans(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Complex spans hierarchy',
            style: theme.textTheme.headline5,
          ),
          TextField(
            onChanged: (value) => _rootOperationName = value,
            enabled: !_performingOperation,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Root Operation Name',
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  child: const Text('Send'),
                  onPressed: _performingOperation ? null : _onSendComplexSpan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onSendSingleSpan() async {
    setState(() {
      _performingOperation = true;
    });

    final operationName =
        _operationName.isEmpty ? 'single span' : _operationName;

    final tracing = DatadogSdk.instance.traces;
    if (tracing != null) {
      var span = tracing.startSpan(
        operationName,
        resourceName: _resourceName.isNotEmpty ? _resourceName : null,
      );
      await Future.delayed(const Duration(seconds: 1));
      span.finish();
    }

    setState(() {
      _performingOperation = false;
    });
  }

  Future<void> _onSendComplexSpan() async {
    setState(() {
      _performingOperation = true;
    });

    final operationName =
        _rootOperationName.isEmpty ? 'complex span' : _rootOperationName;

    final tracing = DatadogSdk.instance.traces;
    if (tracing != null) {
      final rootSpan = tracing.startRootSpan(operationName);
      await Future.delayed(const Duration(milliseconds: 500));

      final child1 =
          tracing.startSpan('child operation 1', parentSpan: rootSpan);
      await Future.delayed(const Duration(milliseconds: 100));
      child1.finish();

      final child2 =
          tracing.startSpan('child operation 2', parentSpan: rootSpan);
      await Future.delayed(const Duration(milliseconds: 500));
      final grandchild =
          tracing.startSpan('grandchild operation', parentSpan: child2);
      await Future.delayed(const Duration(seconds: 1));
      grandchild.finish();
      child2.finish();
      rootSpan.finish();
    }

    setState(() {
      _performingOperation = false;
    });
  }
}
