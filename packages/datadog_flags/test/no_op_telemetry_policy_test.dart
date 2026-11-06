// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// Legacy API compatibility coverage.
// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:test/test.dart';

void main() {
  for (final enabled in [false, true]) {
    for (final control in [true, false, 'true', null]) {
      test(
        'no-op details preserve policy: enabled=$enabled control=${jsonEncode(control)}',
        () async {
          final sdk = DatadogFlags();
          addTearDown(sdk.disable);
          await sdk.enable(
            configuration: DatadogFlagsConfiguration(
              enableEvaluationTelemetryOptOutParameter: enabled,
            ),
          );
          expect(sdk.isEnabled, isFalse);
          final client = sdk.sharedClient();
          await client.initialize(
            FlagsEvaluationContext(
              targetingKey: 'user',
              attributes: {
                FlagsEvaluationContext.evaluationTelemetryOptOutKey: control,
              },
            ),
          );
          final results = [
            client.getBooleanDetails(key: 'b', defaultValue: true),
            client.getStringDetails(key: 's', defaultValue: 'fallback'),
            client.getIntegerDetails(key: 'i', defaultValue: 7),
            client.getDoubleDetails(key: 'd', defaultValue: 1.5),
            client.getObjectDetails(key: 'o', defaultValue: {'fallback': true}),
          ];
          expect(results.map((r) => r.value), [
            true,
            'fallback',
            7,
            1.5,
            {'fallback': true},
          ]);
          for (final result in results) {
            expect(result.error, FlagEvaluationError.providerNotReady);
            expect(
              result.evaluationTelemetryOptedOut,
              enabled && control == true,
            );
          }
          expect(
            sdk
                .sharedClient(name: 'other')
                .getBooleanDetails(key: 'b', defaultValue: false)
                .evaluationTelemetryOptedOut,
            isFalse,
          );
          await client.initialize(
            const FlagsEvaluationContext(targetingKey: 'user'),
          );
          expect(
            client
                .getBooleanDetails(key: 'b', defaultValue: false)
                .evaluationTelemetryOptedOut,
            isFalse,
          );
          await client.initialize(
            const FlagsEvaluationContext(
              attributes: {
                FlagsEvaluationContext.evaluationTelemetryOptOutKey: true,
              },
            ),
          );
          await sdk.reset();
          expect(
            client
                .getBooleanDetails(key: 'b', defaultValue: false)
                .evaluationTelemetryOptedOut,
            isFalse,
          );
          await sdk.disable();
          expect(
            sdk
                .sharedClient()
                .getBooleanDetails(key: 'b', defaultValue: false)
                .evaluationTelemetryOptedOut,
            isFalse,
          );
        },
      );
    }
  }
}
