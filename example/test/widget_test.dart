// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import 'package:datadog_sdk_example/example_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Verify Platform version', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ExampleApp());

    var listView = find.byType(ListView);
    var tile = find.descendant(of: listView, matching: find.byType(ListTile));

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is Text && widget.data!.startsWith('Single'),
      ),
      findsOneWidget,
    );
  });
}
