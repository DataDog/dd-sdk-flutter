// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:meta/meta.dart';

@immutable
class RUMContext {
  final String applicationId;
  final String sessionId;
  final String? viewId;
  final double? viewServerTimeOffset;

  const RUMContext({
    required this.applicationId,
    required this.sessionId,
    this.viewId,
    this.viewServerTimeOffset,
  });

  factory RUMContext.fromMap(Map<Object?, Object?> map) {
    return RUMContext(
      applicationId: map['applicationId'] as String,
      sessionId: map['sessionId'] as String,
      viewId: map['viewId'] as String?,
      viewServerTimeOffset: map['viewServerTimeOffset'] as double?,
    );
  }
}
