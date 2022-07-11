// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// NB: This import is meant to be used by Datadog for implementation of
// extension packages, and is not meant for public use. Anything exposed by this
// file has the potential to change without notice.

import 'dart:math';

export 'src/attributes.dart';
export 'src/rum/attributes.dart';

final Random _traceRandom = Random();

String generateTraceId() {
  // Though traceid is an unsigned 64-bit int, for compatibility
  // we assume it needs to be a positive signed 64-bit int, so only
  // use 63-bits.
  final highBits = _traceRandom.nextInt(1 << 31);
  final lowBits = BigInt.from(_traceRandom.nextInt(1 << 32));

  var traceId = BigInt.from(highBits) << 32;
  traceId += lowBits;

  return traceId.toString();
}
