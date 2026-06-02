// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flags screen evaluates flags and counts emissions',
      (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Flags'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('evaluated'), findsOneWidget);
    expect(find.textContaining('Datadog Flags'), findsOneWidget);
    expect(find.textContaining('variant=enabled'), findsOneWidget);

    await tester.tap(find.text('Flush'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(
      _keyedText('flags-exposure-count', '5'),
      findsOneWidget,
    );
    expect(
      _keyedText('flags-evaluation-request-count', '1'),
      findsOneWidget,
    );
    expect(
      _keyedText('flags-evaluation-event-count', '5'),
      findsOneWidget,
    );
  });
}

Finder _keyedText(String key, String value) {
  return find.byWidgetPredicate((widget) {
    return widget is Text && widget.key == Key(key) && widget.data == value;
  });
}
