// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'dart:math';

import 'package:flutter/material.dart';

final random = Random();

@immutable
class _RandomRange {
  final int low;
  final int high;

  const _RandomRange(this.low, this.high);

  int nextRandom() {
    return random.nextInt(high - low) + low;
  }
}

const _propertyNameRange = _RandomRange(5, 20);
const _stringSizeRange = _RandomRange(100, 1000);

class RandomString {
  static String alphaNumeric =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';

  static String randomAlphaNumeric(int length) {
    return String.fromCharCodes(Iterable.generate(
      length,
      (_) => alphaNumeric.codeUnitAt(random.nextInt(alphaNumeric.length)),
    ));
  }
}

Map<String, Object?> generateLargeContext() {
  const propertyCountRange = _RandomRange(100, 100);
  const nestingLevelRange = _RandomRange(0, 3);

  final properties = propertyCountRange.nextRandom();
  var content = <String, Object?>{};
  for (var i = 0; i < properties; ++i) {
    final property =
        RandomString.randomAlphaNumeric(_propertyNameRange.nextRandom());
    final nestingLevel = nestingLevelRange.nextRandom();
    content[property] = generateProperty(nestingLevel);
  }

  return content;
}

Object generateProperty(int nesting) {
  if (nesting == 0) {
    return RandomString.randomAlphaNumeric(_stringSizeRange.nextRandom());
  }

  const nestedPropertyRange = _RandomRange(8, 12);

  final properties = nestedPropertyRange.nextRandom();
  var content = <String, Object?>{};
  for (var i = 0; i < properties; ++i) {
    final property =
        RandomString.randomAlphaNumeric(_propertyNameRange.nextRandom());
    content[property] = generateProperty(nesting - 1);
  }

  return content;
}
