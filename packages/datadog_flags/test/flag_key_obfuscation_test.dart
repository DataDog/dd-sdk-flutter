// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/assignment.dart';
import 'package:datadog_flags/src/flag_key_obfuscation.dart';
import 'package:datadog_flags/src/intake_platform.dart';
import 'package:datadog_flags/src/precompute_response.dart';
import 'package:datadog_flags/src/version.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _salt = '000102030405060708090a0b0c0d0e0f';
const _descriptor = {'scheme': 'flag-key-sha256-v1', 'salt': _salt};
const _metadata = {'obfuscated': true, 'obfuscation': _descriptor};
const _context = FlagsEvaluationContext(targetingKey: 'athlete-123');

// Shared edge/browser vectors. These expected values do not use this SDK's hash.
const _vectors = {
  'new-route-planner':
      'a60479237ef2f69175bbe0bd581966d1583766941815dc1d414c883767795190',
  'Flag': 'adca75d2141c51b0c0f084c1058edfb8e6e763f91aaf54ca06326d9847bd9586',
  'flag': '9817872c144b018abd77e3915bd77e2c27f4f534dccff8ffaca27361e3a5e1ee',
  ' flag ': 'b1a5f851cc82a3fdf03a461d72a2241584dcf455df1d384e02a937901b3bc80b',
  'café': '3bfa8c3c17c1b61035b98ecf14007cdf5cba5ce61a48e8cfb65f8106541892d3',
  'cafe\u0301':
      '1e8b7ec5e8028a1ec96b38dd37f6ccea041c0a90358904af40ac5810c23c8765',
  '🚲/旗': '94b611e0d3b26b52f6ad66013d1c72f8a92ea109390049759e75d3c8d3aa4dab',
  'a\u0000b':
      'bac134d201be5e7f28fc7019248f0809c2a013b137e866446ee71add2bc344c7',
  '': '072d985b427f536ad0a11b2d4c5e0f7e6f0ff6d23e779e082f75599ce3fe3eba',
};

void main() {
  for (final vector in _vectors.entries) {
    test('matches the shared digest for ${jsonEncode(vector.key)}', () async {
      final encoding = FlagKeyObfuscation.fromSnapshot(_metadata)!;
      expect(encoding.encodeKey(vector.key), vector.value);
      final harness = await _Harness.create(
        _response({vector.value: _assignment('boolean', true)}),
      );
      await harness.client.initialize(_context);
      final details = harness.client.getBooleanDetails(
        key: vector.key,
        defaultValue: false,
      );
      expect(details.value, isTrue);
      expect(details.key, vector.key);
      expect(details.variant, 'variation-456');
      expect(details.reason, 'TARGETING_MATCH');
    });
  }

  test('preserves typed values and public API errors', () async {
    final cases = [
      ('boolean', true),
      ('string', 'visible-value'),
      ('integer', 42),
      ('float', 12.5),
      ('number', 12.5),
      (
        'object',
        <String, Object?>{
          'visible': ['nested', 42]
        }
      ),
    ];
    for (final (type, value) in cases) {
      final harness = await _Harness.create(
        _response({_vectors['flag']!: _assignment(type, value)}),
      );
      await harness.client.initialize(_context);
      final result = switch (type) {
        'boolean' =>
          harness.client.getBooleanDetails(key: 'flag', defaultValue: false),
        'string' =>
          harness.client.getStringDetails(key: 'flag', defaultValue: 'default'),
        'integer' =>
          harness.client.getIntegerDetails(key: 'flag', defaultValue: -1),
        'float' ||
        'number' =>
          harness.client.getDoubleDetails(key: 'flag', defaultValue: -1),
        _ => harness.client.getObjectDetails(key: 'flag', defaultValue: null),
      };
      expect(result.value, value);
      expect(result.key, 'flag');
      expect(result.error, isNull);
      expect(
          harness.client
              .getBooleanDetails(key: 'missing', defaultValue: false)
              .error,
          FlagEvaluationError.flagNotFound);
      expect(
          harness.client
              .getStringDetails(key: 'flag', defaultValue: 'default')
              .error,
          type == 'string' ? isNull : FlagEvaluationError.typeMismatch);
    }
  });

  for (final metadata in [
    <String, Object?>{},
    {'obfuscated': false}
  ]) {
    test('accepts legacy response $metadata', () async {
      final harness = await _Harness.create(_response(
        {'flag': _assignment('boolean', true)},
        metadata: metadata,
      ));
      await harness.client.initialize(_context);
      expect(
          harness.client
              .getBooleanDetails(key: 'flag', defaultValue: false)
              .value,
          isTrue);
    });
  }

  final malformed = <Map<String, Object?>>[
    {'obfuscated': true},
    {'obfuscated': 'true', 'obfuscation': _descriptor},
    {'obfuscated': null},
    {'obfuscated': false, 'obfuscation': _descriptor},
    {'obfuscation': _descriptor},
    {'obfuscated': true, 'obfuscation': null},
    {'obfuscated': true, 'obfuscation': []},
    {
      'obfuscated': true,
      'obfuscation': {..._descriptor, 'scheme': 'flag-key-sha256-v2'}
    },
    for (final salt in [
      '',
      '0' * 30,
      '0' * 34,
      'G' * 32,
      _salt.toUpperCase(),
      '$_salt\n',
      42
    ])
      {
        'obfuscated': true,
        'obfuscation': {..._descriptor, 'salt': salt}
      },
  ];
  for (final metadata in malformed) {
    test('rejects malformed metadata $metadata with no plaintext retry',
        () async {
      final response =
          _response({'flag': _assignment('boolean', true)}, metadata: metadata);
      expect(
          () => PrecomputeResponse.fromJson(response), throwsFormatException);
      final harness = await _Harness.create(response);
      await harness.client.initialize(_context);
      expect(
          harness.client
              .getBooleanDetails(key: 'flag', defaultValue: false)
              .error,
          FlagEvaluationError.providerNotReady);
      expect(harness.assignmentRequests, hasLength(1));
    });
  }

  for (final key in [
    'plaintext-key',
    'a' * 63,
    'a' * 65,
    'A' * 64,
    '${'a' * 64}\n'
  ]) {
    test('rejects malformed encoded map key ${jsonEncode(key)}', () {
      expect(
          () => PrecomputeResponse.fromJson(
              _response({key: _assignment('boolean', true)})),
          throwsFormatException);
    });
  }

  test('never retries a missed encoded lookup as plaintext', () async {
    final digest = _vectors['flag']!;
    final harness = await _Harness.create(
        _response({digest: _assignment('boolean', true)}));
    await harness.client.initialize(_context);
    expect(
        harness.client
            .getBooleanDetails(key: digest, defaultValue: false)
            .error,
        FlagEvaluationError.flagNotFound);
  });

  for (final key in ['\ud800', '\udc00', 'a\ud800b']) {
    test('rejects malformed Unicode ${jsonEncode(key)}', () async {
      final encoding = FlagKeyObfuscation.fromSnapshot(_metadata)!;
      expect(encoding.encodeKey(key), isNull);
      final replacement = utf8.decode(utf8.encode(key));
      final harness = await _Harness.create(_response(
          {encoding.encodeKey(replacement)!: _assignment('boolean', true)}));
      await harness.client.initialize(_context);
      expect(
          harness.client.getBooleanDetails(key: key, defaultValue: false).value,
          isFalse);
    });
  }

  test('stores metadata with assignments and restores only matching contexts',
      () async {
    final store = _JsonStore();
    final harness = await _Harness.create(
        _response({_vectors['flag']!: _assignment('boolean', true)}),
        store: store);
    await harness.client.initialize(_context);
    expect(store.json!['obfuscation'], _descriptor);
    expect((store.json!['encodedFlags'] as Map).keys, [_vectors['flag']]);
    expect(store.json!.containsKey('flags'), isFalse);
    // This is the legacy reader's lookup. It cannot serve an encoded map.
    final legacyRead = _legacyDecode(store.json!);
    expect(legacyRead.flags, isEmpty);
    expect(legacyRead.context, isA<FlagsEvaluationContext>());
    expect(legacyRead.flags[_vectors['flag']], isNull);
    final restored = FlagsData.fromJson(store.json!);
    expect(restored.toJson(), store.json);

    final offline = await _Harness.create(
        _response({}, metadata: {'obfuscated': true}),
        store: store);
    await offline.client.initialize(_context);
    expect(
        offline.client
            .getBooleanDetails(key: 'flag', defaultValue: false)
            .value,
        isTrue);
    await offline.client
        .initialize(const FlagsEvaluationContext(targetingKey: 'other'));
    expect(
        offline.client
            .getBooleanDetails(key: 'flag', defaultValue: false)
            .error,
        FlagEvaluationError.providerNotReady);
    expect(offline.assignmentRequests, hasLength(2));
  });

  test('rejects invalid stored metadata and preserves legacy snapshots', () {
    final legacy = {
      'flags': {'flag': _assignment('boolean', true)},
      'context': _context.toJson(),
      'date': '2026-09-30T00:00:00Z',
    };
    expect(FlagsData.fromJson(legacy).obfuscation, isNull);
    for (final metadata in malformed) {
      expect(() => FlagsData.fromJson({...legacy, ...metadata}),
          throwsFormatException);
    }
    expect(() => FlagsData.fromJson({...legacy, ..._metadata}),
        throwsA(isA<TypeError>()));
    expect(
        () => FlagsData.fromJson(
            {...legacy, ..._metadata, 'encodedFlags': legacy['flags']}),
        throwsFormatException);
    final missingMetadata = {
      'encodedFlags': {_vectors['flag']!: _assignment('boolean', true)},
      'context': _context.toJson(),
      'date': '2026-09-30T00:00:00Z',
    };
    expect(FlagsData.fromJson(missingMetadata).flags, isEmpty);
  });

  test('rejects exact-length hex values with a trailing newline', () {
    expect(
        () => FlagKeyObfuscation.fromSnapshot({
              'obfuscated': true,
              'obfuscation': {..._descriptor, 'salt': '${'0' * 31}\n'},
            }),
        throwsFormatException);
    expect(
        () => PrecomputeResponse.fromJson(_response({
              '${'a' * 63}\n': _assignment('boolean', true),
            })),
        throwsFormatException);
  });

  test('keeps valid same-context memory after an invalid response', () async {
    final harness = await _Harness.create(
        _response({_vectors['flag']!: _assignment('boolean', true)}));
    await harness.client.initialize(_context);
    harness.response = _response({}, metadata: {'obfuscated': true});
    await harness.client.initialize(_context);
    expect(
        harness.client
            .getBooleanDetails(key: 'flag', defaultValue: false)
            .value,
        isTrue);
    expect(harness.assignmentRequests, hasLength(2));
  });

  test(
      'rotates salts atomically and preserves telemetry names and deduplication',
      () async {
    final harness = await _Harness.create(
        _response({_vectors['flag']!: _assignment('boolean', true)}));
    await harness.client.initialize(_context);
    harness.client.getBooleanDetails(key: 'flag', defaultValue: false);
    final rotated = {
      'obfuscated': true,
      'obfuscation': {..._descriptor, 'salt': 'f' * 32}
    };
    final encoding = FlagKeyObfuscation.fromSnapshot(rotated)!;
    harness.response = _response(
        {encoding.encodeKey('flag')!: _assignment('boolean', true)},
        metadata: rotated);
    await harness.client.initialize(_context);
    expect(
        harness.client
            .getBooleanDetails(key: 'flag', defaultValue: false)
            .value,
        isTrue);
    await harness.sdk.disable();

    final exposures = harness.requests
        .where((request) => request.url.path == '/api/v2/exposures')
        .expand((request) => request.body.trim().split('\n').map(jsonDecode))
        .toList();
    expect(exposures, hasLength(1));
    expect(exposures.single['flag'], {'key': 'flag'});
    expect(exposures.single['variant'], {'key': 'variation-456'});
    expect(exposures.single['allocation'], {'key': 'allocation-123'});
    final evaluations = harness.requests
        .where((request) => request.url.path == '/api/v2/flagevaluation')
        .expand((request) => isWebFlagsIntake
            ? request.body.trim().split('\n').map(jsonDecode)
            : (jsonDecode(request.body)['flagEvaluations'] as List));
    expect(evaluations, isNotEmpty);
    expect(
        evaluations.every((event) => event['flag']['key'] == 'flag'), isTrue);
  });

  test(
      'advertises automatic support and the actual Dart implementation version',
      () async {
    final harness = await _Harness.create(_response({}));
    await harness.client.initialize(_context);
    final attributes =
        jsonDecode(harness.assignmentRequests.single.body)['data']
            ['attributes'];
    expect(attributes['source'],
        {'sdk_name': 'dd-sdk-dart', 'sdk_version': ddPackageVersion});
    expect(attributes.containsKey('supported_capabilities'), isFalse);
    expect(
        harness.assignmentRequests.single
            .headers['X-DD-FEATURE-FLAGS-CAPABILITIES'],
        'assignment-encoding-flag-key-256-v1');
  });
}

Map<String, Object?> _assignment(String type, Object value) => {
      'allocationKey': 'allocation-123',
      'variationKey': 'variation-456',
      'variationType': type,
      'variationValue': value,
      'reason': 'TARGETING_MATCH',
      'doLog': true,
      'serialId': 123,
    };

Map<String, Object?> _response(Map<String, Object?> flags,
        {Map<String, Object?> metadata = _metadata}) =>
    {
      'data': {
        'attributes': {
          'createdAt': '2026-09-30T00:00:00Z',
          ...metadata,
          'flags': flags
        }
      },
    };

class _JsonStore implements DatadogFlagsStore {
  Map<String, Object?>? json;
  @override
  Future<FlagsData?> read(String clientName) async =>
      json == null ? null : FlagsData.fromJson(json!);
  @override
  Future<void> write(String clientName, FlagsData data) async {
    json = jsonDecode(jsonEncode(data.toJson())) as Map<String, Object?>;
  }

  @override
  Future<void> delete(String clientName) async {
    json = null;
  }
}

// Frozen FlagsData.fromJson implementation from the pre-encoding SDK (1.2.0).
// This verifies downgrade behavior with the old decoder, which ignores metadata.
FlagsData _legacyDecode(Map<String, Object?> json) {
  final flags = json['flags'] as Map<String, Object?>? ?? const {};
  return FlagsData(
    flags: flags.map((key, value) {
      return MapEntry(
        key,
        FlagAssignment.fromJson(Map<String, Object?>.from(value as Map)),
      );
    }),
    context: FlagsEvaluationContext.fromJson(
      Map<String, Object?>.from(json['context'] as Map),
    ),
    date: DateTime.parse(json['date'] as String),
  );
}

class _Harness {
  final sdk = DatadogFlags();
  final requests = <http.Request>[];
  Map<String, Object?> response;
  DatadogFlagsClient get client => sdk.sharedClient();
  List<http.Request> get assignmentRequests => requests
      .where((request) => request.url.path == '/precompute-assignments')
      .toList();
  _Harness(this.response);

  static Future<_Harness> create(Map<String, Object?> response,
      {DatadogFlagsStore? store}) async {
    final harness = _Harness(response);
    await harness.sdk.enable(
        configuration: DatadogFlagsConfiguration(
      datadogConfig: const DatadogFlagsConfig(
          clientToken: 'test-token', env: 'test', site: DatadogFlagsSite.us1),
      store: store,
      httpClient: MockClient((request) async {
        harness.requests.add(request);
        return http.Response(
            request.url.path == '/precompute-assignments'
                ? jsonEncode(harness.response)
                : '{}',
            200);
      }),
    ));
    addTearDown(harness.sdk.disable);
    return harness;
  }
}
