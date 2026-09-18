// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/services.dart';

typedef TextMasker = String Function(String);

String maskTextPreservingSpaces(String text) {
  StringBuffer buffer = StringBuffer();
  for (final char in text.codeUnits) {
    if (TextLayoutMetrics.isWhitespace(char)) {
      buffer.writeCharCode(char);
    } else {
      buffer.write('x');
    }
  }
  return buffer.toString();
}

String maskTextFixedLength(String text) {
  return '***';
}
