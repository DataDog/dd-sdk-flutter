// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.
import 'dart:math';

import 'package:collection/collection.dart';

final _random = Random();
const _alphas = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _numerics = '0123456789';
const _alphaNumerics = _alphas + _numerics;

String randomString({int length = 10}) {
  final result = String.fromCharCodes(Iterable.generate(
    length,
    (_) => _alphaNumerics.codeUnitAt(_random.nextInt(_alphaNumerics.length)),
  ));

  return result;
}

bool randomBool() {
  return _random.nextBool();
}

extension RandomExtension<T> on List<T> {
  T randomElement() {
    return this[_random.nextInt(length)];
  }
}

extension DurationHelpers on Duration {
  /// The number of whole nanoseconds spanned by this [Duration].
  ///
  /// Note, Dart only has precision up to the microsecond level, so the last
  /// digits of this value will always be zero.
  /// ```
  int get inNanoseconds {
    return inMicroseconds * 1000;
  }
}

Map<String, String> getDdTraceState(String header) {
  final list = header.split(',');
  final ddTraceState =
      list.firstWhereOrNull((e) => e.startsWith('dd='))?.substring(3);
  if (ddTraceState == null) return {};

  return ddTraceState.split(';').fold<Map<String, String>>({},
      (Map<String, String> value, element) {
    final split = element.split(':');
    value[split[0]] = split[1];
    return value;
  });
}
