// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'datadog_flags.dart';
import 'flags_context.dart';
import 'flags_details.dart';

abstract interface class DatadogFlagsClient {
  static const defaultName = 'default';

  String get name;

  static Future<DatadogFlagsClient> create({
    String name = defaultName,
  }) {
    return DatadogFlags.createClient(name: name);
  }

  static DatadogFlagsClient shared({
    String name = defaultName,
  }) {
    return DatadogFlags.sharedClient(name: name);
  }

  Future<void> setEvaluationContext(
    DatadogFlagsEvaluationContext context,
  );

  FlagDetails<bool> getBooleanDetails({
    required String key,
    required bool defaultValue,
  });

  bool getBooleanValue({
    required String key,
    required bool defaultValue,
  });

  FlagDetails<String> getStringDetails({
    required String key,
    required String defaultValue,
  });

  String getStringValue({
    required String key,
    required String defaultValue,
  });

  FlagDetails<int> getIntegerDetails({
    required String key,
    required int defaultValue,
  });

  int getIntegerValue({
    required String key,
    required int defaultValue,
  });

  FlagDetails<double> getDoubleDetails({
    required String key,
    required double defaultValue,
  });

  double getDoubleValue({
    required String key,
    required double defaultValue,
  });

  FlagDetails<Object?> getObjectDetails({
    required String key,
    required Object? defaultValue,
  });

  Object? getObjectValue({
    required String key,
    required Object? defaultValue,
  });

  Future<void> flush();

  Future<void> reset();

  Future<void> dispose();
}
