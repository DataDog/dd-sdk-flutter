// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

class RumScreen extends StatefulWidget {
  const RumScreen({super.key});

  @override
  State<RumScreen> createState() => _RumScreenState();
}

class _RumScreenState extends State<RumScreen> {
  var viewStarted = false;
  var actionStarted = false;
  var resourceStarted = false;
  final TextEditingController _viewNameController =
      TextEditingController(text: 'RUM Test View');
  String? _currentSessionId;

  static const actionName = 'checkout-flow';

  @override
  void initState() {
    _getCurrentSessionId();

    super.initState();
  }

  @override
  void dispose() {
    if (viewStarted) {
      _stopView();
    }

    super.dispose();
  }

  void _getCurrentSessionId() async {
    _currentSessionId = await DatadogSdk.instance.rum?.getCurrentSessionId();

    if (mounted) {
      setState(() {});
    }
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

      // Because web may not start a session until after a view is started,
      // refresh the current session id after starting a view.
      _getCurrentSessionId();
    }
  }

  void _stopView() {
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

  void _startAction() {
    DatadogSdk.instance.rum?.startAction(RumActionType.custom, actionName, {});

    setState(() {
      actionStarted = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Action $actionName Started'),
    ));
  }

  void _stopAction() {
    DatadogSdk.instance.rum?.stopAction(RumActionType.custom, actionName, {
      'completed': true,
    });

    setState(() {
      actionStarted = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Action $actionName Stopped'),
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
      rum.stopResource(resourceKey, 200, RumResourceType.image, 1024);
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Resource $resource Stopped'),
    ));

    setState(() {
      resourceStarted = false;
    });
  }

  void _stopResourceWithError() {
    var rum = DatadogSdk.instance.rum;
    if (rum != null) {
      rum.stopResourceWithErrorInfo(
        resourceKey,
        'Simulated network failure',
        'NetworkError',
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Resource $resource Stopped With Error'),
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
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
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
                    const SizedBox(height: 8),
                    const Text(
                      'Start/Stop Action (tracks errors, resources, long tasks)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (viewStarted && !actionStarted)
                                ? _startAction
                                : null,
                            child: const Text('▶ Start Action'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (viewStarted && actionStarted)
                                ? _stopAction
                                : null,
                            child: const Text('◼ Stop Action'),
                          ),
                        ),
                      ],
                    ),
                    if (actionStarted)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '✓ Action "checkout-flow" is active\nErrors, resources, and long tasks will be attributed to this action',
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Resource Tracking',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (viewStarted && !resourceStarted)
                                ? _startResource
                                : null,
                            child: const Text('Start Resource'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (viewStarted && resourceStarted)
                                ? _stopResource
                                : null,
                            child: const Text('Stop (200)'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade100,
                            ),
                            onPressed: (viewStarted && resourceStarted)
                                ? _stopResourceWithError
                                : null,
                            child: const Text('Stop (Error)'),
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
            Positioned(
                bottom: 0,
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  alignment: Alignment.center,
                  child: Text(
                    'Current Session Id:\n$_currentSessionId',
                    textAlign: TextAlign.center,
                  ),
                )),
          ],
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
