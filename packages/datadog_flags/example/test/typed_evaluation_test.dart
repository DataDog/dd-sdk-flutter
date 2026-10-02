// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:datadog_flags/datadog_flags.dart';
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
  for (final early in [true, false]) {
    test(
        'event Future retains notification ${early ? 'before' : 'after'} app construction returns',
        () async {
      final owner = DatadogFlags();
      addTearDown(owner.disable);
      final firstFlags = Completer<FlagsClientEvent>();
      const context = FlagsEvaluationContext(targetingKey: 'example-user');
      // Application factory, not a new SDK construction API. Initialization in
      // Dart is explicit; this covers both possible app handoff orderings.
      Future<DatadogFlagsClient> construct() async {
        await owner.enable(
            configuration: DatadogFlagsConfiguration(
          datadogConfig: const DatadogFlagsConfig(
              clientToken: 'token', env: 'test', site: DatadogFlagsSite.us1),
          httpClient: MockClient((_) async => _assignments(false)),
          onFirstFlags: firstFlags.complete,
        ));
        final client = owner.sharedClient();
        if (early) await client.initialize(context);
        return client;
      }

      final client = await construct().timeout(const Duration(seconds: 1));
      expect(firstFlags.isCompleted, early);
      var reads = 0;
      final handled = firstFlags.future.then((event) {
        expect(event.flagsChanged, ['checkout.enabled']);
        expect(
            client
                .getBooleanDetails(key: 'checkout.enabled', defaultValue: false)
                .value,
            isTrue);
        reads++;
      });
      if (!early) await client.initialize(context);
      await handled.timeout(const Duration(seconds: 1));
      expect(reads, 1);
    });
  }

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
