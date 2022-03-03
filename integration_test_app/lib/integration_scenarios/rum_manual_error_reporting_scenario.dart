// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter/material.dart';

class RumManualErrorReportingScenario extends StatefulWidget {
  const RumManualErrorReportingScenario({Key? key}) : super(key: key);

  @override
  _RumManualErrorReportingScenarioState createState() =>
      _RumManualErrorReportingScenarioState();
}

class _RumManualErrorReportingScenarioState
    extends State<RumManualErrorReportingScenario> {
  @override
  void initState() {
    super.initState();

    DatadogSdk.instance.rum
        ?.startView('my-key', 'RumManualErrorReportingScenario');
    _addErrors();
  }

  void _addErrors() {
    final rum = DatadogSdk.instance.rum;
    if (rum != null) {
      rum.addError(NullThrownError(), RumErrorSource.source);
      rum.addErrorInfo('Rum error message', RumErrorSource.network);
    }
  }

  Future<void> _throwAndCatchError() async {
    try {
      throw const OSError('This was an error!', 200);
    } catch (e, s) {
      DatadogSdk.instance.rum
          ?.addError(e, RumErrorSource.source, stackTrace: s);
    }
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
        ],
      ),
    );
  }
}
