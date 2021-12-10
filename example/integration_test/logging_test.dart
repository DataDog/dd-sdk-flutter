import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:datadog_sdk_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('tap on the floating action button, verify counter',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      var listView = find.byType(ListView);
      var tile = find.descendant(of: listView, matching: find.byType(ListTile));

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is Text && widget.data!.startsWith('Single'),
        ),
        findsOneWidget,
      );
    });
  });
}
