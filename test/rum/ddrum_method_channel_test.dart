import 'package:datadog_sdk/rum/ddrum_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class MockType {
  final int value;

  MockType(this.value);

  @override
  String toString() {
    return 'MockType($value)';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DdRumMethodChannel ddRumPlatform;
  final List<MethodCall> log = [];

  setUp(() {
    ddRumPlatform = DdRumMethodChannel();
    ddRumPlatform.methodChannel.setMockMethodCallHandler((call) async {
      log.add(call);
      return null;
    });
  });

  tearDown(() {
    log.clear();
  });

  test('startView calls to platform', () async {
    await ddRumPlatform.startView('my_key', 'my_name', {'attribute': 'value'});

    expect(log, <Matcher>[
      isMethodCall('startView', arguments: {
        'key': 'my_key',
        'name': 'my_name',
        'attributes': {'attribute': 'value'}
      })
    ]);
  });

  test('startView with invalid attributes does not throw', () async {
    final m = MockType(5);
    await ddRumPlatform.startView('my key', 'my_name', {'badAttribute': m});

    expect(log, isEmpty);
  });

  test('stopView calls to platform', () async {
    await ddRumPlatform.stopView('my_key', {'stop_attribute': 'my_value'});

    expect(log, <Matcher>[
      isMethodCall('stopView', arguments: {
        'key': 'my_key',
        'attributes': {'stop_attribute': 'my_value'}
      })
    ]);
  });

  test('stopView with invalid attributes does not throw', () async {
    final m = MockType(5);
    await ddRumPlatform.stopView('my key', {'badAttribute': m});

    expect(log, isEmpty);
  });

  test('addTiming calls to platform', () async {
    await ddRumPlatform.addTiming('my timing name');

    expect(log, <Matcher>[
      isMethodCall('addTiming', arguments: {'name': 'my timing name'})
    ]);
  });
}
