import 'dart:io';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:datadog_sdk/rum/ddrum.dart';
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

    DatadogSdk.instance.ddRum
        ?.startView('my-key', 'RumManualErrorReportingScenario')
        .then((_) => _addErrors());
  }

  Future<void> _addErrors() async {
    final rum = DatadogSdk.instance.ddRum;
    if (rum != null) {
      await rum.addError(NullThrownError(), RumErrorSource.source);
      await rum.addErrorInfo('Rum error message', RumErrorSource.network);
    }
  }

  Future<void> _throwAndCatchError() async {
    try {
      throw const OSError('This was an error!', 200);
    } catch (e, s) {
      await DatadogSdk.instance.ddRum
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
