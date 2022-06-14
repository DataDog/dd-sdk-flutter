import 'package:datadog_flutter_plugin/src/helpers.dart';
import 'package:datadog_flutter_plugin/src/internal_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class SimpleObject {
  final String property;

  SimpleObject(this.property);

  @override
  String toString() {
    return 'SimpleObject($property)';
  }
}

class MockInternalLog extends Mock implements InternalLogger {}

void main() {
  test('findInvalidAttribute returns null on valid values', () {
    final value = {
      'value1': 10,
      'value2': 'Testing!',
      'value3': {
        'internal_value': 'xyz',
        'value_4': 3,
      },
      // This is valid and should be translated by native SDKs to:
      // {
      //  '1': 'value',
      //  '2': 'value'
      // }
      'intMap': {
        1: 'value',
        2: 'value2',
      },
    };

    final val = findInvalidAttribute(value);
    expect(val, isNull);
  });

  test(
      'findInvalidAttribute returns property name and type for invalid property at root',
      () {
    final value = {
      'value1': 10,
      'value2': 'Testing!',
      'object': SimpleObject('testing'),
    };

    final val = findInvalidAttribute(value);
    expect(val, isNotNull);
    expect(val!.propertyName, 'object');
    expect(val.propertyType, 'SimpleObject');
  });

  test('findInvalidAttribute returns property name in nested maps', () {
    final value = {
      'value1': 10,
      'value2': 'Testing!',
      'value3': {'object': SimpleObject('testing'), 'internal_value': 3},
    };

    final val = findInvalidAttribute(value);
    expect(val, isNotNull);
    expect(val!.propertyName, 'value3.object');
    expect(val.propertyType, 'SimpleObject');
  });

  test('findInvalidAttribute returns index of bad property in list', () {
    final value = {
      'value1': 10,
      'value2': 'Testing!',
      'list': [1, 2, SimpleObject('value')],
    };

    final val = findInvalidAttribute(value);
    expect(val, isNotNull);
    expect(val!.propertyName, 'list[2]');
    expect(val.propertyType, 'SimpleObject');
  });

  test('findInvalidAttribute finds bad attribute in nested list', () {
    final value = {
      'value1': 10,
      'value2': 'Testing!',
      'list': [
        1,
        2,
        {
          'value': 10,
          'object': SimpleObject('value'),
        },
      ],
    };

    final val = findInvalidAttribute(value);
    expect(val, isNotNull);
    expect(val!.propertyName, 'list[2].object');
    expect(val.propertyType, 'SimpleObject');
  });

  test('findInvalidAttribute finds bad attribute in list of lists', () {
    final value = {
      'value1': 10,
      'value2': 'Testing!',
      'list': [
        1,
        2,
        [
          10,
          SimpleObject('value'),
        ],
      ],
    };

    final val = findInvalidAttribute(value);
    expect(val, isNotNull);
    expect(val!.propertyName, 'list[2][1]');
    expect(val.propertyType, 'SimpleObject');
  });

  test('findInvalidAttribute reports invalid map', () {
    final value = {
      'value1': 10,
      'value2': 'Testing!',
      'list': [
        1,
        2,
        [
          10,
          SimpleObject('value'),
        ],
      ],
    };

    final val = findInvalidAttribute(value);
    expect(val, isNotNull);
    expect(val!.propertyName, 'list[2][1]');
    expect(val.propertyType, 'SimpleObject');
  });

  test('findInvalidAttribute reports invalid key used in map', () {
    final value = {
      'value1': 10,
      'value2': 'Testing!',
      'value3': {
        SimpleObject('property'): [
          1,
          2,
        ],
      }
    };

    final val = findInvalidAttribute(value);
    expect(val, isNotNull);
    expect(val!.propertyName, 'Key: value3.SimpleObject(property)');
    expect(val.propertyType, 'SimpleObject');
  });

  test('wrap sends logs bad attributes when an argument error is thrown',
      () async {
    final testValue = {
      'value1': {
        'internal_value': 'test',
      },
      'value2': 'testing',
      'value3': SimpleObject('property'),
    };
    final mockLogger = MockInternalLog();

    wrap('testMethod', mockLogger, testValue, () async {
      throw ArgumentError();
    });

    // Wait for the next set of microtasks
    await Future<void>.microtask(() {});

    verify(() => mockLogger.warn(any(
          that: allOf(
            contains('value3'),
            contains('SimpleObject'),
          ),
        )));
  });
}
