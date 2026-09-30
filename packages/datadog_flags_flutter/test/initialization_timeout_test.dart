// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatadogFlagsClient extends Mock implements DatadogFlagsClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(FlagsEvaluationContext.empty);
  });

  test('exports the core initialization timeout exception', () {
    const error = FlagsInitializationTimeoutException(
      clientName: 'shop',
      timeout: Duration(milliseconds: 2500),
    );

    expect(error.clientName, 'shop');
    expect(error.timeout, const Duration(milliseconds: 2500));
    expect(
      error.message,
      'Flags client "shop" did not initialize within 2500 ms.',
    );
  });

  test('forwards initialization timeout errors from the core client', () async {
    const error = FlagsInitializationTimeoutException(
      clientName: 'shop',
      timeout: Duration(milliseconds: 2500),
    );
    final delegate = _MockDatadogFlagsClient();
    when(() => delegate.initialize(any())).thenThrow(error);
    final client = DatadogFlutterFlagsClient(
      name: 'shop',
      resolveDelegate: () async => delegate,
      addRumFeatureFlagEvaluation: null,
    );

    await expectLater(
      client.initialize(FlagsEvaluationContext.empty),
      throwsA(same(error)),
    );
  });
}
