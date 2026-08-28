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
  // Held as a field, not a local: `DatadogLogging.createLogger` attaches a
  // `Finalizer` that calls `destroyLogger` once the Dart logger is unreachable,
  // and the native logger drops any writes still queued on the SDK's context
  // queue when it goes away. A local would be collectable as soon as
  // `initState` returns, which silently loses logs on a loaded machine.
  DatadogLogger? logger;

  @override
  void initState() {
    super.initState();

    logger =
        DatadogSdk.instance.logs?.createLogger(DatadogLoggerConfiguration());

    logger?.info('Log without default user and account information.');

    DatadogSdk.instance.addUserExtraInfo({'fetch_status': 'waiting_for_ball'});
    logger?.info('Log with only extra info.');

    // Set a user - same as other users in integration scenarios
    DatadogSdk.instance.setUserInfo(
      id: 'bits',
      name: 'Bits Dawoof',
      email: 'bits@datadoghq.com',
      extraInfo: {'type': 'dog'},
    );
    DatadogSdk.instance.addUserExtraInfo({'department': 'data'});
    logger?.info('Log with user set, default account information.');

    // Set account
    DatadogSdk.instance.setAccountInfo(
      id: 'bits-account',
      name: 'Dawoof, Bits',
      extraInfo: {'type': 'top_dog'},
    );
    DatadogSdk.instance.addAccountExtraInfo({'department': 'fetching'});
    logger?.info('User and account set');

    // Clear user
    DatadogSdk.instance.clearUserInfo();
    logger?.info('User info cleared');

    // Clear account
    DatadogSdk.instance.clearAccountInfo();
    logger?.info('Account info cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logging Scenario')),
      body: Container(),
    );
  }
}
