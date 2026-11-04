// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';
import 'package:test/test.dart';

import 'support/datadog_provider_fixture.dart';

void main() {
  test(
    'anonymous fixture assignments use the transport targeting key',
    () async {
      final fixture = DatadogProviderFixture();
      addTearDown(fixture.close);
      fixture.setFlags(null, {'enabled': true});
      await fixture.datadog.initialize(EvaluationContext.empty);
      final result = fixture.datadog.resolveBooleanValue(
        'enabled',
        false,
        EvaluationContext.empty,
      );
      expect(result.value, isTrue);
      expect(result.errorCode, isNull);
    },
  );
}
