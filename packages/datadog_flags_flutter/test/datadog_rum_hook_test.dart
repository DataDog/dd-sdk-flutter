// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk_experimental.dart'
    show createIsolatedOpenFeatureAPI;

class _Sdk extends Mock implements DatadogSdk {}

class _Rum extends Mock implements DatadogRum {}

class _Provider extends Mock implements FeatureProvider {}

final class _ThrowingAfterHook extends HookAdapter {
  @override
  void after(
    HookContext context,
    FlagEvaluationDetails<Object> details,
    HookHints hints,
  ) => throw StateError('after hook failed');
}

void main() {
  setUpAll(() => registerFallbackValue(EvaluationContext.empty));

  late _Rum rum;
  late OpenFeatureAPI api;
  late DatadogRumHook hook;

  setUp(() async {
    final sdk = _Sdk();
    rum = _Rum();
    when(() => sdk.rum).thenReturn(rum);
    final provider = _Provider();
    when(
      () => provider.metadata,
    ).thenReturn(const ProviderMetadata(name: 'test'));
    when(() => provider.resolveBooleanValue(any(), any(), any())).thenAnswer(
      (invocation) => switch (invocation.positionalArguments[0]) {
        'enabled' => ResolutionDetails(
          value: true,
          variant: 'on',
          reason: 'TARGETING_MATCH',
        ),
        'error-with-variant' => ResolutionDetails(
          value: false,
          variant: 'on',
          errorCode: ErrorCode.general,
          reason: 'ERROR',
        ),
        'error-reason' => ResolutionDetails(
          value: false,
          variant: 'on',
          reason: 'ERROR',
        ),
        'static' => ResolutionDetails(value: true, reason: 'STATIC'),
        _ => ResolutionDetails(
          value: invocation.positionalArguments[1] as bool,
          errorCode: ErrorCode.flagNotFound,
          reason: 'ERROR',
        ),
      },
    );
    api = createIsolatedOpenFeatureAPI();
    addTearDown(api.shutdown);
    await api.setProviderAndWait(provider);
    hook = DatadogRumHook(sdk: sdk);
  });

  test('tags the variant of a successful evaluation', () {
    final client = api.getClient()..addHooks([hook]);

    expect(client.getBooleanValue('enabled', false), isTrue);
    verify(() => rum.addFeatureFlagEvaluation('enabled', 'on')).called(1);
  });

  for (final (name, flagKey, expected) in [
    ('an error result', 'missing', false),
    ('an error with a variant', 'error-with-variant', false),
    ('an ERROR reason with a variant', 'error-reason', false),
    ('a result without a variant', 'static', true),
  ]) {
    test('does not tag $name', () {
      final client = api.getClient()..addHooks([hook]);

      expect(client.getBooleanValue(flagKey, false), expected);
      verifyZeroInteractions(rum);
    });
  }

  test('does not tag an evaluation that a later after hook fails', () {
    api.addHooks([_ThrowingAfterHook()]);
    final client = api.getClient()..addHooks([hook]);

    expect(client.getBooleanValue('enabled', false), isFalse);
    verifyZeroInteractions(rum);
  });
}
