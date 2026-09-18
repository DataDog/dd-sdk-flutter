// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/widgets.dart' show Color;

int _floatToInt8(double x) {
  return (x * 255.0).safeRound() & 0xff;
}

extension HexColor on Color {
  String toHexString() {
    int rint = _floatToInt8(r);
    int gint = _floatToInt8(g);
    int bint = _floatToInt8(b);
    int aint = _floatToInt8(a);
    return '#${rint.toRadixString(16).padLeft(2, '0')}'
        '${gint.toRadixString(16).padLeft(2, '0')}'
        '${bint.toRadixString(16).padLeft(2, '0')}'
        '${aint.toRadixString(16).padLeft(2, '0')}';
  }
}

extension SafeDouble on double {
  int safeRound([int fallback = 0]) {
    if (isFinite) {
      return round();
    }
    return fallback;
  }
}
