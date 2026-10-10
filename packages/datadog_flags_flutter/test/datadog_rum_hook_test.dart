// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk_experimental.dart';

class _Sdk extends Mock implements DatadogSdk {}

class _Rum extends Mock implements DatadogRum {}

void main() {
  test(
    'OpenFeature hook tags successful evaluations and skips errors',
    () async {
      final sdk = _Sdk();
      final rum = _Rum();
      when(() => sdk.rum).thenReturn(rum);
      final api = createIsolatedOpenFeatureAPI();
      addTearDown(api.shutdown);
      await api.setProviderAndWait(InMemoryProvider({'enabled': true}));
      final client = api.getClient();
      client.addHooks([DatadogRumHook(sdk: sdk)]);
      expect(client.getBooleanValue('enabled', false), isTrue);
      verify(() => rum.addFeatureFlagEvaluation('enabled', true)).called(1);
      client.getBooleanValue('missing', false);
      client.getStringValue('enabled', 'fallback');
      verifyNoMoreInteractions(rum);
    },
  );
}
