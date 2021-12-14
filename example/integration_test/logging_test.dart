// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:datadog_sdk_example/main.dart' as app;

import 'tools/log_keys.dart';
import 'tools/mock_http_sever.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late MockHttpServer mockHttpServer;

  setUpAll(() async {
    mockHttpServer = MockHttpServer();
    await mockHttpServer.start();
  });

  Future<void> openTestScenariosPane(WidgetTester tester) async {
    app.testingConfiguration =
        app.TestingConfiguration(customEndpoint: 'http://localhost:2221');
    mockHttpServer.startNewSession();

    app.main();
    await tester.pumpAndSettle();

    var integrationItem = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data!.startsWith('Integration'));
    await tester.tap(integrationItem);
    await tester.pumpAndSettle();
  }

  testWidgets('test logging scenario 1', (WidgetTester tester) async {
    await openTestScenariosPane(tester);

    var logScenario = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Text && widget.data!.startsWith('Logging Scenario'),
    );
    await tester.tap(logScenario);
    await tester.pumpAndSettle();

    var logs = <Map<String, Object?>>[];

    await mockHttpServer.pullRecordedRequests(
      const Duration(seconds: 30),
      (requests) {
        requests
            .map((e) => (e.requestJson as List))
            .expand((e) => e)
            .forEach((e) => logs.add(e as Map<String, dynamic>));

        return logs.length >= 4;
      },
    );
    expect(logs.length, greaterThanOrEqualTo(4));

    expect(logs[0][LogKeys.status], 'debug');
    expect(logs[0][LogKeys.message], 'debug message');

    expect(logs[1][LogKeys.status], 'info');
    expect(logs[1][LogKeys.message], 'info message');

    expect(logs[2][LogKeys.status], 'warn');
    expect(logs[2][LogKeys.message], 'warn message');

    expect(logs[3][LogKeys.status], 'error');
    expect(logs[3][LogKeys.message], 'error message');
  });
}
