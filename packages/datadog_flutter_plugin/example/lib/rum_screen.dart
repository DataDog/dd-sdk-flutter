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
  var viewStarted = false;
  var resourceStarted = false;
  final TextEditingController _viewNameController =
      TextEditingController(text: 'RUM Test View');

  @override
  void dispose() {
    if (viewStarted) {
      _stopView();
    }

    super.dispose();
  }

  void _startView() async {
    var rum = DatadogSdk.instance.rum;
    if (rum != null) {
      final viewName = _viewNameController.value.text;
      rum.startView(viewName);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('View $viewName Started'),
      ));

      setState(() {
        viewStarted = true;
      });
    }
  }

  _stopView() {
    var rum = DatadogSdk.instance.rum;
    if (rum != null) {
      final viewName = _viewNameController.value.text;
      rum.stopView(viewName);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('View $viewName Stopped'),
      ));

      setState(() {
        viewStarted = false;
      });
    }
  }

  void _sendAction() {
    const name = 'Test Action';
    DatadogSdk.instance.rum?.addAction(RumActionType.custom, name);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Sent Action $name'),
    ));
  }

  static const resourceKey = 'ResourceKey';
  static const resource = '/testing/url';

  void _startResource() {
    setState(() {
      resourceStarted = true;
    });

    var rum = DatadogSdk.instance.rum;
    if (rum != null) {
      rum.startResource(resourceKey, RumHttpMethod.get, resource);
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Resource $resource Started'),
    ));
  }

  void _stopResource() {
    var rum = DatadogSdk.instance.rum;
    if (rum != null) {
      rum.stopResource(resourceKey, 200, RumResourceType.image);
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Resource $resource Stopped'),
    ));

    setState(() {
      resourceStarted = false;
    });
  }

  void _sendError() {
    try {
      throw Exception('We threw an exception!');
    } catch (e, st) {
      DatadogSdk.instance.rum?.addError(
        e,
        RumErrorSource.source,
        stackTrace: st,
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sent Exception $e')));
    }
  }

  void _triggerLongTask() {
    final done = DateTime.now().add(const Duration(milliseconds: 200));
    while (DateTime.now().isBefore(done)) {
      // noop
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Triggered Long Task')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RUM'),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _defaultTextField(
                label: 'View Name',
                controller: _viewNameController,
                enabled: !viewStarted,
              ),
              ElevatedButton(
                onPressed: viewStarted ? null : _startView,
                child: const Text('Start View'),
              ),
              Row(
                //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (viewStarted && !resourceStarted)
                          ? _startResource
                          : null,
                      child: const Text('Start Resource'),
                    ),
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (viewStarted && resourceStarted)
                          ? _stopResource
                          : null,
                      child: const Text('Stop Resource'),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: viewStarted ? _sendAction : null,
                child: const Text('Send Action'),
              ),
              ElevatedButton(
                onPressed: viewStarted ? _sendError : null,
                child: const Text('Send Error'),
              ),
              ElevatedButton(
                onPressed: viewStarted ? _triggerLongTask : null,
                child: const Text('Trigger Long Task'),
              ),
              ElevatedButton(
                onPressed: viewStarted ? _stopView : null,
                child: const Text('Stop View'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultTextField({
    required String label,
    ValueChanged<String>? onChanged,
    TextEditingController? controller,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      child: TextField(
        enabled: enabled,
        onChanged: onChanged,
        controller: controller,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }
}
