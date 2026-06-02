// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'flags_error.dart';

class FlagDetails<T> {
  final String key;
  final T value;
  final String? variant;
  final String? reason;
  final FlagEvaluationError? error;

  const FlagDetails({
    required this.key,
    required this.value,
    this.variant,
    this.reason,
    this.error,
  });
}
