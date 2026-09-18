// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
// ignore: library_annotations
@TestOn('browser')

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/src/web_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trackingConsentToWeb', () {
    test('converts granted to "granted"', () {
      expect(TrackingConsent.granted.webValue(), 'granted');
    });

    test('converts notGranted to "not-granted"', () {
      expect(TrackingConsent.notGranted.webValue(), 'not-granted');
    });

    test('converts pending to "not-granted"', () {
      expect(TrackingConsent.pending.webValue(), 'not-granted');
    });
  });
  group('value to js', () {
    test('converts simple values', () {
      expect(1, (valueToJs(1, 'integer') as JSNumber).toDartInt);
      expect(3.1415, (valueToJs(3.1415, 'double') as JSNumber).toDartDouble);
      expect('Test String',
          (valueToJs('Test String', 'string') as JSString).toDart);
      expect(false, (valueToJs(false, 'bool') as JSBoolean).toDart);
    });

    test('converts map values', () {
      final mapValue = {
        'integer': 1,
        'double': 3.1415,
        'bool': false,
        'string': 'Test String',
      };

      final jsMap = valueToJs(mapValue, 'map') as JSObject;
      expect(1, (jsMap.getProperty('integer'.toJS) as JSNumber).toDartInt);
      expect(
          3.1415, (jsMap.getProperty('double'.toJS) as JSNumber).toDartDouble);
      expect(false, (jsMap.getProperty('bool'.toJS) as JSBoolean).toDart);
      expect(
          'Test String', (jsMap.getProperty('string'.toJS) as JSString).toDart);
    });

    test('converts nested map values', () {
      final mapValue = {
        'object': {
          'integer': 1,
          'double': 3.1415,
          'bool': false,
          'string': 'Test String',
        },
      };

      final jsMap = valueToJs(mapValue, 'map') as JSObject;
      final innerMap = jsMap.getProperty('object'.toJS) as JSObject;
      expect(1, (innerMap.getProperty('integer'.toJS) as JSNumber).toDartInt);
      expect(3.1415,
          (innerMap.getProperty('double'.toJS) as JSNumber).toDartDouble);
      expect(false, (innerMap.getProperty('bool'.toJS) as JSBoolean).toDart);
      expect('Test String',
          (innerMap.getProperty('string'.toJS) as JSString).toDart);
    });

    test('converts integer array', () {
      final array = [1, 2, 22, 45];

      final jsArray = valueToJs(array, 'array') as JSArray;
      final jsDartArray = jsArray.toDart;
      expect(1, (jsDartArray[0] as JSNumber).toDartInt);
      expect(2, (jsDartArray[1] as JSNumber).toDartInt);
      expect(22, (jsDartArray[2] as JSNumber).toDartInt);
      expect(45, (jsDartArray[3] as JSNumber).toDartInt);
    });

    test('converts string array', () {
      final array = ['a', 'b', 'long string', 'longer string'];

      final jsArray = valueToJs(array, 'array') as JSArray;
      final jsDartArray = jsArray.toDart;
      expect('a', (jsDartArray[0] as JSString).toDart);
      expect('b', (jsDartArray[1] as JSString).toDart);
      expect('long string', (jsDartArray[2] as JSString).toDart);
      expect('longer string', (jsDartArray[3] as JSString).toDart);
    });

    test('converts complex object', () {
      final mapValue = {
        'integer': 1,
        'double': 3.1415,
        'object': {
          'array_test': [14, 23, 11],
          'string': 'test string'
        },
        'flags': ['my_flag', 'another_flag']
      };

      final jsMap = valueToJs(mapValue, 'map') as JSObject;
      expect(1, (jsMap.getProperty('integer'.toJS) as JSNumber).toDartInt);
      expect(
          3.1415, (jsMap.getProperty('double'.toJS) as JSNumber).toDartDouble);
      final innerMap = jsMap.getProperty('object'.toJS) as JSObject;
      final testArray =
          (innerMap.getProperty('array_test'.toJS) as JSArray).toDart;
      expect(14, (testArray[0] as JSNumber).toDartInt);
      expect(23, (testArray[1] as JSNumber).toDartInt);
      expect(11, (testArray[2] as JSNumber).toDartInt);
      expect('test string',
          (innerMap.getProperty('string'.toJS) as JSString).toDart);

      final flagsArray = (jsMap.getProperty('flags'.toJS) as JSArray).toDart;
      expect('my_flag', (flagsArray[0] as JSString).toDart);
      expect('another_flag', (flagsArray[1] as JSString).toDart);
    });
  });
}
