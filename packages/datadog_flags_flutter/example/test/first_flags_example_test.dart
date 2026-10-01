// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:datadog_flags_flutter_example/main.dart' as example;

void main() {
  for (final empty in [false, true]) {
    testWidgets(
        'actual app logs keys and renders callback evaluation (empty=$empty)',
        (tester) async {
      expect(const String.fromEnvironment('DD_CLIENT_TOKEN'), isNotEmpty,
          reason: 'Run with --dart-define=DD_CLIENT_TOKEN=test-token');
      DatadogSdk.initializeForTesting();
      final messages = <String?>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => messages.add(message);
      try {
        await http.runWithClient(
          () => example.main(),
          () => MockClient((_) async => _assignments(empty)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
            messages.where(
                (line) => line?.startsWith('First installed flags:') ?? false),
            [
              empty
                  ? 'First installed flags: []'
                  : 'First installed flags: [checkout.enabled]'
            ]);
        expect(find.text('First flags value'), findsOneWidget);
        expect(find.text('${!empty}'), findsNWidgets(2));
        expect(find.text('ready'), findsOneWidget);
        await tester.ensureVisible(find.text('Evaluate flag'));
        await tester.tap(find.text('Evaluate flag'));
        await tester.pumpAndSettle();
        expect(
            messages.where(
                (line) => line?.startsWith('First installed flags:') ?? false),
            hasLength(1));
        final app = tester.widget<example.FlagsExampleApp>(
            find.byType(example.FlagsExampleApp));
        await tester.pumpWidget(const SizedBox.shrink());
        app.firstFlagsDetails.dispose();
      } finally {
        debugPrint = originalDebugPrint;
        await DatadogSdk.instance.flushAndDeinitialize();
      }
    }, skip: const String.fromEnvironment('DD_CLIENT_TOKEN').isEmpty);
  }
}

http.Response _assignments(bool empty) => http.Response(
    jsonEncode({
      'data': {
        'attributes': {
          'flags': empty
              ? {}
              : {
                  'checkout.enabled': {
                    'allocationKey': 'allocation',
                    'variationKey': 'enabled',
                    'variationType': 'boolean',
                    'variationValue': true,
                    'reason': 'TARGETING_MATCH',
                    'doLog': false
                  },
                }
        }
      }
    }),
    200);
