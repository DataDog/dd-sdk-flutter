// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags/datadog_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';
import 'package:test_app/flags/flags_example_config.dart';
import 'package:test_app/screens/flags_screen.dart';

void main() {
  testWidgets('refresh can be reached outside the initial list viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = OpenFeatureAPI.instance;
    addTearDown(api.shutdown);
    dotenv.testLoad(fileInput: 'FLAGS_TARGETING_KEY=widget-test');
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FlagsScreen(
          config: FlagsExampleConfig.fromDotEnv(
            clientToken: '',
            env: 'test',
            site: DatadogFlagsSite.us1,
            applicationId: null,
          ),
          client: api.getClient(),
          refresh: () async {
            refreshes++;
          },
        ),
      ),
    );
    final refreshButton = find.widgetWithText(
      ElevatedButton,
      'Refresh assignments',
    );
    // ensureVisible cannot find an element until ListView builds the row.
    expect(refreshButton, findsNothing);
    await tester.scrollUntilVisible(refreshButton, 300);
    await tester.tap(refreshButton);
    await tester.pumpAndSettle();
    expect(refreshes, 1);
    expect(tester.takeException(), isNull);
  });
}
