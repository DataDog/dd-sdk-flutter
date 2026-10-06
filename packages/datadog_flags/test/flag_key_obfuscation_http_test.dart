// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:test/test.dart';

void main() {
  test(
      'public API consumes an edge response over HTTP and restores its file cache',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final directory =
        await Directory.systemTemp.createTemp('flags-obfuscation-');
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    final store = _FileStore(File('${directory.path}/assignments.json'));
    final bodies = <Map<String, dynamic>>[];
    final capabilities = <String?>[];
    var response = <String, Object?>{
      'data': {
        'attributes': {
          'obfuscated': true,
          'obfuscation': {
            'scheme': 'flag-key-sha256-v1',
            'salt': '000102030405060708090a0b0c0d0e0f'
          },
          'flags': {
            '9817872c144b018abd77e3915bd77e2c27f4f534dccff8ffaca27361e3a5e1ee':
                _assignment('boolean', true),
            'adca75d2141c51b0c0f084c1058edfb8e6e763f91aaf54ca06326d9847bd9586':
                _assignment('string', 'visible value'),
            'b1a5f851cc82a3fdf03a461d72a2241584dcf455df1d384e02a937901b3bc80b':
                _assignment('integer', 42),
            '3bfa8c3c17c1b61035b98ecf14007cdf5cba5ce61a48e8cfb65f8106541892d3':
                _assignment('number', 0.25),
            '1e8b7ec5e8028a1ec96b38dd37f6ccea041c0a90358904af40ac5810c23c8765':
                _assignment('object', {
              'visible': [42, true]
            }),
          },
        }
      }
    };
    server.listen((request) async {
      capabilities
          .add(request.headers.value('X-DD-FEATURE-FLAGS-CAPABILITIES'));
      bodies.add(jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
    final configuration = DatadogFlagsConfiguration(
      datadogConfig: const DatadogFlagsConfig(
          clientToken: 'test-token', env: 'test', site: DatadogFlagsSite.us1),
      customFlagsEndpoint:
          Uri.parse('http://127.0.0.1:${server.port}/precompute-assignments'),
      trackExposures: false,
      trackEvaluations: false,
      store: store,
    );
    final sdk = DatadogFlags();
    addTearDown(sdk.disable);
    await sdk.enable(configuration: configuration);
    const context = FlagsEvaluationContext(targetingKey: 'subject');
    final client = sdk.sharedClient();
    await client.initialize(context);
    expect(client.getBooleanDetails(key: 'flag', defaultValue: false).value,
        isTrue);
    expect(client.getStringDetails(key: 'Flag', defaultValue: '').value,
        'visible value');
    expect(client.getIntegerDetails(key: ' flag ', defaultValue: -1).value, 42);
    expect(client.getDoubleDetails(key: 'café', defaultValue: -1).value, 0.25);
    expect(
        client.getObjectDetails(key: 'cafe\u0301', defaultValue: null).value, {
      'visible': [42, true]
    });
    expect(
        bodies.single['data']['attributes']
            .containsKey('supported_capabilities'),
        isFalse);
    expect(capabilities.single, 'assignment-encoding-flag-key-256-v1');
    expect(bodies.single['data']['attributes']['source']['sdk_name'],
        'dd-sdk-dart');
    final disk = jsonDecode(await store.file.readAsString()) as Map;
    expect(disk.containsKey('flags'), isFalse);
    expect(
        (disk['encodedFlags'] as Map)
            .keys
            .every((key) => (key as String).length == 64),
        isTrue);
    await sdk.disable();

    response = {
      'data': {
        'attributes': {'obfuscated': true, 'flags': {}}
      }
    };
    final restored = DatadogFlags();
    addTearDown(restored.disable);
    await restored.enable(configuration: configuration);
    await restored.sharedClient().initialize(context);
    expect(
        restored
            .sharedClient()
            .getBooleanDetails(key: 'flag', defaultValue: false)
            .value,
        isTrue);
    expect(bodies, hasLength(2));
  });
}

Map<String, Object?> _assignment(String type, Object value) => {
      'allocationKey': 'allocation',
      'variationKey': 'variant',
      'variationType': type,
      'variationValue': value,
      'reason': 'TARGETING_MATCH',
      'doLog': true,
    };

class _FileStore implements DatadogFlagsStore {
  final File file;
  _FileStore(this.file);
  @override
  Future<FlagsData?> read(String clientName) async => await file.exists()
      ? FlagsData.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, Object?>)
      : null;
  @override
  Future<void> write(String clientName, FlagsData data) =>
      file.writeAsString(jsonEncode(data.toJson()));
  @override
  Future<void> delete(String clientName) async {
    if (await file.exists()) await file.delete();
  }
}
