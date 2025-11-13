// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

class LoggingUserAccountScenario extends StatefulWidget {
  const LoggingUserAccountScenario({Key? key}) : super(key: key);

  @override
  State<LoggingUserAccountScenario> createState() =>
      _LoggingUserAccountScenarioState();
}

class _LoggingUserAccountScenarioState
    extends State<LoggingUserAccountScenario> {
  late DatadogLogger logger;
  late DatadogLogger secondLogger;

  @override
  void initState() {
    super.initState();

    final log =
        DatadogSdk.instance.logs?.createLogger(DatadogLoggerConfiguration());

    log?.info('Log without default user and account information.');

    // Set a user - same as other users in integration scenarios
    DatadogSdk.instance.setUserInfo(
        id: 'bits',
        name: 'Bits Dawoof',
        email: 'bits@datadoghq.com',
        extraInfo: {
          'type': 'dog',
        });
    DatadogSdk.instance.addUserExtraInfo({'department': 'data'});
    log?.info('Log with user set, default account information.');

    // Set account
    DatadogSdk.instance.setAccountInfo(
        id: 'bits-account',
        name: 'Dawoof, Bits',
        extraInfo: {'type': 'top_dog'});
    DatadogSdk.instance.addAccountExtraInfo({'department': 'fetching'});
    log?.info('User and account set');

    // Clear user
    DatadogSdk.instance.clearUserInfo();
    log?.info('User info cleared');

    // Clear account
    DatadogSdk.instance.clearAccountInfo();
    log?.info('Account info cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logging Scenario'),
      ),
      body: Container(),
    );
  }
}
