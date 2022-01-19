// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datadog_integration_test_app/main.dart' as app;

import 'tools/mock_http_sever.dart';

class _IsDecimalVersionOfHex extends CustomMatcher {
  _IsDecimalVersionOfHex(Object? valueOrMatcher)
      : super(
          "Decimal string who's hex representation is",
          'hex string',
          valueOrMatcher is String
              ? valueOrMatcher.toLowerCase()
              : valueOrMatcher,
        );

  @override
  Object? featureValueOf(dynamic actual) =>
      int.parse(actual).toRadixString(16).toLowerCase();
}

Matcher isDecimalVersionOfHex(Object value) => _IsDecimalVersionOfHex(value);

MockHttpServer? mockHttpServer;

Future<void> openTestScenario(WidgetTester tester, String scenarioName) async {
  if (mockHttpServer == null) {
    mockHttpServer = MockHttpServer();
    unawaited(mockHttpServer!.start());
  }

  // These need to be set as const in order to work, so we
  // can't refactor this out to a function.
  const clientToken = bool.hasEnvironment('DD_CLIENT_TOKEN')
      ? String.fromEnvironment('DD_CLIENT_TOKEN')
      : null;
  const applicationId = bool.hasEnvironment('DD_APPLICATION_ID')
      ? String.fromEnvironment('DD_APPLICATION_ID')
      : null;

  app.testingConfiguration = app.TestingConfiguration(
      customEndpoint: mockHttpServer!.endpoint,
      clientToken: clientToken,
      applicationId: applicationId);
  mockHttpServer!.startNewSession();

  await app.main();
  await tester.pumpAndSettle();

  var integrationItem = find.byWidgetPredicate((widget) =>
      widget is Text && (widget.data?.startsWith(scenarioName) ?? false));
  await tester.tap(integrationItem);
  await tester.pumpAndSettle();
}
