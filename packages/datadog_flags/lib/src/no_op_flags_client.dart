// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'evaluation_context.dart';
import 'flags_client.dart';
import 'flags_error.dart';

class NoOpDatadogFlagsClient implements DatadogFlagsClient {
  @override
  final String name;

  const NoOpDatadogFlagsClient({required this.name});

  @override
  Future<void> initialize(FlagsEvaluationContext context) async {}

  @override
  FlagDetails<bool> getBooleanDetails({
    required String key,
    required bool defaultValue,
  }) {
    return _details(key: key, defaultValue: defaultValue);
  }

  @override
  FlagDetails<String> getStringDetails({
    required String key,
    required String defaultValue,
  }) {
    return _details(key: key, defaultValue: defaultValue);
  }

  @override
  FlagDetails<int> getIntegerDetails({
    required String key,
    required int defaultValue,
  }) {
    return _details(key: key, defaultValue: defaultValue);
  }

  @override
  FlagDetails<double> getDoubleDetails({
    required String key,
    required double defaultValue,
  }) {
    return _details(key: key, defaultValue: defaultValue);
  }

  @override
  FlagDetails<Object?> getObjectDetails({
    required String key,
    required Object? defaultValue,
  }) {
    return _details(key: key, defaultValue: defaultValue);
  }

  @override
  Future<void> reset() async {}

  @override
  Future<void> shutdown() async {}

  FlagDetails<T> _details<T>({
    required String key,
    required T defaultValue,
  }) {
    return FlagDetails(
      key: key,
      value: defaultValue,
      error: FlagEvaluationError.providerNotReady,
    );
  }
}
