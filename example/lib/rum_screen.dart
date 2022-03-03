// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter/material.dart';

class RumScreen extends StatefulWidget {
  const RumScreen({Key? key}) : super(key: key);

  @override
  _RumScreenState createState() => _RumScreenState();
}

class _RumScreenState extends State<RumScreen> {
  var performingOperation = false;

  var viewKey = '';
  var viewName = '';
  var actionType = '';
  var resourceName = '';
  var errorMessage = '';

  Future<void> _sendViewEvent() async {
    setState(() {
      performingOperation = true;
    });

    var actualKey = viewKey.isEmpty ? 'FooRumScreen' : viewKey;
    var actualViewName = viewName.isEmpty ? null : viewName;
    var rum = DatadogSdk.instance.rum;
    if (rum != null) {
      rum.startView(actualKey, actualViewName);
      await Future.delayed(const Duration(seconds: 2));
      rum.stopView(actualKey);
    }

    setState(() {
      performingOperation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RUM'),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'View Info',
                style: theme.textTheme.headline5,
              ),
              _defaultTextField(
                label: 'Key',
                enabled: !performingOperation,
                onChanged: (value) => viewKey = value,
              ),
              _defaultTextField(
                label: 'Name',
                enabled: !performingOperation,
                onChanged: (value) => viewName = value,
              ),
              ElevatedButton(
                onPressed: performingOperation ? null : _sendViewEvent,
                child: const Text('Send View Event'),
              ),
              _viewEventField(
                label: 'Action',
                enabled: !performingOperation,
                onChanged: (value) => actionType = value,
                onSend: () {},
              ),
              _viewEventField(
                label: 'Resource',
                enabled: !performingOperation,
                onChanged: (value) => resourceName = value,
                onSend: () {},
              ),
              _viewEventField(
                label: 'Error',
                enabled: !performingOperation,
                onChanged: (value) => errorMessage = value,
                onSend: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultTextField({
    required String label,
    required ValueChanged<String> onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      child: TextField(
        enabled: enabled,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }

  Widget _viewEventField({
    required String label,
    required ValueChanged<String> onChanged,
    required VoidCallback onSend,
    bool enabled = true,
  }) {
    var theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label Event',
          style: theme.textTheme.headline5,
        ),
        Row(children: [
          Expanded(
            child: _defaultTextField(
              label: label,
              enabled: enabled,
              onChanged: (value) {},
            ),
          ),
          ElevatedButton(
            onPressed: enabled ? onSend : null,
            child: const Text('Send'),
          )
        ])
      ],
    );
  }
}
