// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:meta/meta.dart';

/// Original JSON number used to validate getters before floating-point rounding.
@immutable
final class NumericValue {
  final String literal;
  final int? integer;
  final double? floating;

  NumericValue._(this.literal, this.integer, this.floating);

  factory NumericValue(String literal) {
    if (!RegExp(
      r'^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$',
    ).hasMatch(literal)) {
      throw const FormatException('Invalid numeric literal');
    }
    final negative = literal.startsWith('-');
    final parts = (negative ? literal.substring(1) : literal)
        .toLowerCase()
        .split('e');
    final significand = parts.first.split('.');
    var digits = significand.join().replaceFirst(RegExp(r'^0+'), '');
    if (digits.isEmpty) return NumericValue._(literal, 0, 0);
    final exponent = parts.length == 2
        ? int.tryParse(parts[1]) ??
              (parts[1].startsWith('-') ? -1000000 : 1000000)
        : 0;
    // Only the sign matters beyond the token length and Double's decimal range.
    var scale =
        exponent.clamp(-literal.length - 1000, literal.length + 1000) -
        (significand.length == 2 ? significand[1].length : 0);
    while (digits.endsWith('0')) {
      digits = digits.substring(0, digits.length - 1);
      scale++;
    }
    final whole = scale >= 0;
    final wholeText = whole && scale <= 309 && digits.length <= 309 - scale
        ? '${negative ? '-' : ''}$digits${'0' * scale}'
        : null;
    final exact = wholeText == null ? null : BigInt.parse(wholeText);
    final parsedInteger = wholeText == null || digits.length + scale > 19
        ? null
        : int.tryParse(wholeText);
    final integer =
        parsedInteger != null &&
            exact! >= BigInt.parse('-9223372036854775808') &&
            exact <= BigInt.parse('9223372036854775807') &&
            BigInt.from(parsedInteger) == exact
        ? parsedInteger
        : null;
    final parsedDouble = double.tryParse(literal);
    final floating =
        parsedDouble != null &&
            parsedDouble.isFinite &&
            parsedDouble != 0 &&
            (!whole || (exact != null && BigInt.from(parsedDouble) == exact))
        ? parsedDouble
        : null;
    return NumericValue._(literal, integer, floating);
  }
}

/// Decode the envelope normally, retaining original numeric assignment tokens.
Map<String, Object?> decodeNumericAssignments(String text) {
  final decoded = Map<String, Object?>.from(jsonDecode(text) as Map);
  // Strings are copied verbatim. Only tokens outside strings are quoted.
  final quoted = StringBuffer();
  var index = 0;
  while (index < text.length) {
    final char = text[index];
    if (char == '"') {
      quoted.write(char);
      index++;
      while (index < text.length) {
        final next = text[index++];
        quoted.write(next);
        if (next == r'\' && index < text.length) {
          quoted.write(text[index++]);
        } else if (next == '"') {
          break;
        }
      }
    } else if (char == '-' ||
        (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57)) {
      final start = index++;
      while (index < text.length && '0123456789.eE+-'.contains(text[index])) {
        index++;
      }
      quoted.write(jsonEncode(text.substring(start, index)));
    } else {
      quoted.write(char);
      index++;
    }
  }
  final original = jsonDecode(quoted.toString());
  final data = decoded['data'];
  final attributes = data is Map ? data['attributes'] : null;
  final flags = attributes is Map ? attributes['flags'] : null;
  if (flags is Map) {
    for (final entry in flags.entries) {
      final assignment = entry.value;
      if (assignment is Map &&
          assignment['variationValue'] is num &&
          const [
            'number',
            'integer',
            'float',
          ].contains(assignment['variationType'])) {
        assignment['variationValue'] = NumericValue(
          original['data']['attributes']['flags'][entry.key]['variationValue']
              as String,
        );
      }
    }
  }
  return decoded;
}
