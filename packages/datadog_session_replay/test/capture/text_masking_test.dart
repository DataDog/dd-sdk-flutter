// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/src/capture/text_masking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maskTextPreservingSpaces masks simple text', () {
    // Given
    final string = randomString();

    // When
    final maskedString = maskTextPreservingSpaces(string);

    // Then
    expect(maskedString, 'x' * string.length);
  });

  test('maskTextPreservingSpaces masks preserving spaces', () {
    // Given
    final string = 'Simple text with spaces.';

    // When
    final maskedString = maskTextPreservingSpaces(string);

    // Then
    expect(maskedString, 'xxxxxx xxxx xxxx xxxxxxx');
  });

  test('maskTextPreservingSpaces masks preserving other whitespace', () {
    // Given
    final string = '''A string with
lots of
\tother white space.''';

    // When
    final maskedString = maskTextPreservingSpaces(string);

    // Then
    final expectedString = '''x xxxxxx xxxx
xxxx xx
\txxxxx xxxxx xxxxxx''';

    expect(maskedString, expectedString);
  });

  test('maskTextFixedLength always returns same string', () {
    // Given
    final smallStirng = 'a';
    final random = randomString();
    final longString =
        'A very long string with spaces which is why it did not use randomString';

    // When
    final maskedSmallString = maskTextFixedLength(smallStirng);
    final maskedRandomStirng = maskTextFixedLength(random);
    final maskedLongString = maskTextFixedLength(longString);

    // Then
    final expectedString = '***';
    expect(maskedSmallString, expectedString);
    expect(maskedRandomStirng, expectedString);
    expect(maskedLongString, expectedString);
  });
}
