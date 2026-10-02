// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../bin/typed_evaluation.dart' as example;

class _Output implements Stdout {
  final buffer = StringBuffer();
  @override
  void writeln([Object? object = '']) => buffer.writeln(object);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final empty in [false, true]) {
    test(
        'actual CLI logs installed keys and evaluates its selected flag (empty=$empty)',
        () async {
      final output = _Output();
      await IOOverrides.runZoned(
        () => http.runWithClient(
          () => example.main(['--targeting-key', 'example-user']),
          () => MockClient((_) async => _assignments(empty)),
        ),
        stdout: () => output,
      );
      final lines = output.buffer.toString().split('\n');
      expect(lines.where((line) => line.startsWith('First installed flags:')), [
        empty
            ? 'First installed flags: []'
            : 'First installed flags: [checkout.enabled]'
      ]);
      // The callback and the existing post-initialization evaluation both run.
      expect(
          lines.where((line) => line == 'key: checkout.enabled'), hasLength(2));
      expect(lines.where((line) => line == 'value: ${!empty}'), hasLength(2));
      if (!empty) {
        expect(lines.where((line) => line == 'variant: enabled'), hasLength(2));
        expect(lines.where((line) => line == 'error: (none)'), hasLength(2));
      }
    });
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
