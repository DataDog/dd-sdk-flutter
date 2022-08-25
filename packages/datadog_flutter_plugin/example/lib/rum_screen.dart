// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

class RumScreen extends StatefulWidget {
  const RumScreen({Key? key}) : super(key: key);

  @override
  State<RumScreen> createState() => _RumScreenState();
}

class _RumScreenState extends State<RumScreen> {
  var performingOperation = false;
  var inView = false;

  var viewKey = '';
  var viewName = '';
  var actionName = '';
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

  Future<void> _startView() async {
    var actualKey = viewKey.isEmpty ? 'FooRumScreen' : viewKey;
    var actualViewName = viewName.isEmpty ? null : viewName;
    var rum = DatadogSdk.instance.rum;
    if (rum != null) {
      rum.startView(actualKey, actualViewName);
    }

    setState(() {
      inView = true;
    });
  }

  _stopView() {
    var actualKey = viewKey.isEmpty ? 'FooRumScreen' : viewKey;
    var rum = DatadogSdk.instance.rum;
    if (rum != null) {
      rum.stopView(actualKey);
    }

    setState(() {
      inView = false;
    });
  }

  void _sendAction() {
    DatadogSdk.instance.rum
        ?.addUserAction(RumUserActionType.custom, actionName);
  }

  void _sendResource() async {
    setState(() {
      performingOperation = true;
    });

    var resourceKey = 'ResourceKey';
    var resource = resourceName.isEmpty ? '/testing/url' : resourceName;

    var rum = DatadogSdk.instance.rum;
    if (rum != null) {
      rum.startResourceLoading(resourceKey, RumHttpMethod.get, resource);
      await Future.delayed(const Duration(seconds: 2));
      rum.stopResourceLoading(resourceKey, 200, RumResourceType.native);
    }

    setState(() {
      performingOperation = false;
    });
  }

  void _triggerLongTask() {
    final done = DateTime.now().add(const Duration(milliseconds: 200));
    while (DateTime.now().isBefore(done)) {
      // noop
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    bool canStartView = !performingOperation && !inView;
    bool canStopView = !performingOperation && inView;

    return RumUserActionDetector(
      rum: DatadogSdk.instance.rum,
      child: Scaffold(
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
                  enabled: canStartView,
                  onChanged: (value) => viewKey = value,
                ),
                _defaultTextField(
                  label: 'Name',
                  enabled: canStartView,
                  onChanged: (value) => viewName = value,
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: canStartView ? _sendViewEvent : null,
                      child: const Text('Send View Event'),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: canStartView ? _startView : null,
                      child: const Text('Start View'),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: canStopView ? _stopView : null,
                      child: const Text('Stop View'),
                    ),
                  ],
                ),
                _viewEventField(
                  label: 'Action',
                  enabled: !performingOperation,
                  onChanged: (value) => actionName = value,
                  onSend: _sendAction,
                ),
                _viewEventField(
                  label: 'Resource',
                  enabled: !performingOperation,
                  onChanged: (value) => resourceName = value,
                  onSend: _sendResource,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Buttons',
                      style: theme.textTheme.headline5,
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.plumbing),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.add),
                        ),
                        ElevatedButton(
                          onPressed: () => _triggerLongTask(),
                          child: const Text('Trigger Long Task'),
                        ),
                      ],
                    ),
                  ],
                )
              ],
            ),
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
              onChanged: onChanged,
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
