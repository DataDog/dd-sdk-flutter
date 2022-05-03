// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:math';

final random = Random();

String generateTraceId() {
  final highBits = random.nextInt(1 << 32);
  final lowBits = BigInt.from(random.nextInt(1 << 32));

  var traceId = BigInt.from(highBits) << 32;
  traceId += lowBits;

  return traceId.toString();
}
