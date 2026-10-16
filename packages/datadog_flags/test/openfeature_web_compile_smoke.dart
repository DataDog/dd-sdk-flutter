// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags/datadog_flags.dart';

// Compile with `dart compile js test/openfeature_web_compile_smoke.dart`.
// This checks that the public provider can compile without the test runner.
// Browser unit tests cover runtime behavior; this is an optional build probe.
void main() {
  final provider = DatadogOpenFeatureProvider(
    configuration: const DatadogFlagsConfiguration(
      datadogConfig: DatadogFlagsConfig(
        clientToken: 'client-token',
        env: 'test',
        site: DatadogFlagsSite.us1,
      ),
    ),
  );
  if (provider.metadata.name.isEmpty) {
    throw StateError('Provider metadata must have a name.');
  }
}
