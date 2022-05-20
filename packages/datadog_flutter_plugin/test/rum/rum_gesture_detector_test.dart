// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/src/rum/ddrum.dart';
import 'package:datadog_flutter_plugin/src/rum/rum_gesture_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDdRum extends Mock implements DdRum {}

Widget _buildSimpleApp(DdRum rum) {
  return RumGestureDetector(
    rum: rum,
    child: MaterialApp(
      color: Colors.blueAccent,
      home: Column(
        children: [
          const Text('This is Text'),
          ElevatedButton(
            onPressed: () {},
            child: const Text('This is a button'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('tap button reports tap to RUM', (tester) async {
    final mockRum = MockDdRum();

    await tester.pumpWidget(_buildSimpleApp(mockRum));

    final button = find.byType(ElevatedButton);
    await tester.tap(button);

    verify(() => mockRum.addUserAction(RumUserActionType.tap, any()));
  });
}
