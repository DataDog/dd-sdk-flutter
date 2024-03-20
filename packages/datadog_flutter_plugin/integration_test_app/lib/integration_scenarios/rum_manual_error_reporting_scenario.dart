// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/material.dart';

class RumManualErrorReportingScenario extends StatefulWidget {
  const RumManualErrorReportingScenario({Key? key}) : super(key: key);

  @override
  State<RumManualErrorReportingScenario> createState() =>
      _RumManualErrorReportingScenarioState();
}

class _RumManualErrorReportingScenarioState
    extends State<RumManualErrorReportingScenario> {
  final viewKey = 'my-key';

  @override
  void initState() {
    super.initState();

    DatadogSdk.instance.rum
        ?.startView(viewKey, 'RumManualErrorReportingScenario');
    _addErrors();
  }

  void _addErrors() {
    final rum = DatadogSdk.instance.rum;
    if (rum != null) {
      rum.addError(
        TypeError(),
        RumErrorSource.source,
        errorType: 'NullThrown',
      );
      rum.addErrorInfo('Rum error message', RumErrorSource.network,
          attributes: {
            DatadogAttributes.errorFingerprint: 'custom-fingerprint',
          },);
    }
  }

  void _throwAndCatchError() {
    try {
      throw const OSError('This was an error!', 200);
    } catch (e, s) {
      DatadogSdk.instance.rum
          ?.addError(e, RumErrorSource.source, stackTrace: s);
    }
  }

  void _stopView() {
    // Manually stop the view to send all error events
    DatadogSdk.instance.rum?.stopView(viewKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RUM Errors'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _throwAndCatchError,
            child: const Text('Throw / Catch Exception'),
          ),
          ElevatedButton(
            onPressed: _stopView,
            child: const Text('Stop View'),
          )
        ],
      ),
    );
  }
}
