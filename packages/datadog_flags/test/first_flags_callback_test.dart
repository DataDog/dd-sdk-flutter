// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _context = FlagsEvaluationContext(targetingKey: 'example-user');

Map<String, Object?> _flag(bool value) => {
      'allocationKey': 'allocation',
      'variationKey': 'variant',
      'variationType': 'boolean',
      'variationValue': value,
      'reason': 'TARGETING_MATCH',
      'doLog': true,
    };

http.Response _response(
        [Map<String, bool> flags = const {'checkout.enabled': true}]) =>
    http.Response(
        jsonEncode({
          'data': {
            'attributes': {
              'flags': flags.map((key, value) => MapEntry(key, _flag(value))),
            }
          }
        }),
        200);

FlagsData _cached({String subject = 'example-user', bool empty = false}) =>
    FlagsData.fromJson({
      'context': {'targetingKey': subject},
      'date': '2026-10-01T00:00:00.000Z',
      'flags': empty ? <String, Object?>{} : {'checkout.enabled': _flag(false)},
    });

class _Store implements DatadogFlagsStore {
  final Future<FlagsData?> Function() load;
  Future<void> Function(FlagsData)? save;
  _Store(this.load);
  @override
  Future<FlagsData?> read(String name) async => await load();
  @override
  Future<void> write(String name, FlagsData data) async {
    await save?.call(data);
  }

  @override
  Future<void> delete(String name) async {}
}

Future<DatadogFlags> _owner({
  required void Function(FlagsClientEvent) callback,
  DatadogFlagsStore? store,
  Future<http.Response> Function(http.Request)? request,
  Duration? timeout,
}) async {
  final flags = DatadogFlags();
  await flags.enable(
      configuration: DatadogFlagsConfiguration(
    datadogConfig: const DatadogFlagsConfig(
        clientToken: 'client-token', env: 'test', site: DatadogFlagsSite.us1),
    store: store,
    initializationTimeout: timeout,
    httpClient: MockClient(request ?? (_) async => _response()),
  ));
  flags.sharedClient().onFirstFlags(callback);
  addTearDown(flags.disable);
  return flags;
}

void main() {
  test(
      'cache callback can evaluate before pending network initialization completes',
      () async {
    final network = Completer<http.Response>();
    final delivered = Completer<void>();
    late DatadogFlagsClient client;
    FlagDetails<bool>? early;
    final events = <FlagsClientEvent>[];
    final flags = await _owner(
        store: _Store(() async => _cached()),
        request: (_) => network.future,
        callback: (event) {
          early = client.getBooleanDetails(
              key: 'checkout.enabled', defaultValue: true);
          events.add(event);
          delivered.complete();
        });
    client = flags.sharedClient();
    var completed = false;
    final init = client.initialize(_context).then((_) => completed = true);
    await delivered.future;
    expect(completed, isFalse);
    expect(early!.value, isFalse);
    expect(early!.reason, 'CACHED');
    expect(events.single.flagsChanged, ['checkout.enabled']);
    network.complete(_response());
    await init;
    expect(events, hasLength(1));
    expect(
        client
            .getBooleanDetails(key: 'checkout.enabled', defaultValue: false)
            .value,
        isTrue);
  });

  for (final fromCache in [false, true]) {
    test('accepted empty ${fromCache ? 'cache' : 'network'} notifies with []',
        () async {
      final delivered = Completer<FlagsClientEvent>();
      final network = Completer<http.Response>();
      final flags = await _owner(
          callback: delivered.complete,
          store: fromCache ? _Store(() async => _cached(empty: true)) : null,
          request: (_) =>
              fromCache ? network.future : Future.value(_response({})));
      var initialized = false;
      final initialize = flags
          .sharedClient()
          .initialize(_context)
          .then((_) => initialized = true);
      final event = await delivered.future;
      expect(event.type, FlagsClientEventType.configurationChanged);
      expect(event.flagsChanged, isEmpty);
      if (fromCache) {
        expect(initialized, isFalse);
        network.complete(_response({'later': true}));
      }
      await initialize;
    });
  }

  for (final empty in [false, true]) {
    test(
        'accepted cache keys are immutable and detached from source (empty=$empty)',
        () async {
      final cached = _cached(empty: empty);
      final originalKeys = cached.flags.keys.toList();
      final network = Completer<http.Response>();
      final delivered = Completer<FlagsClientEvent>();
      final flags = await _owner(
          callback: delivered.complete,
          store: _Store(() async => cached),
          request: (_) => network.future);
      final initialize = flags.sharedClient().initialize(_context);
      final event = await delivered.future;
      cached.flags.clear();
      cached.flags['later'] = _cached().flags.values.single;
      expect(event.flagsChanged, originalKeys);
      expect(() => event.flagsChanged!.add('mutation'), throwsUnsupportedError);
      expect(() => event.flagsChanged!.clear(), throwsUnsupportedError);
      if (!empty) {
        expect(
            () => event.flagsChanged![0] = 'mutation', throwsUnsupportedError);
      }
      network.complete(_response({'network': true}));
      await initialize;
      final replay = Completer<FlagsClientEvent>();
      flags.sharedClient().onFirstFlags(replay.complete);
      expect(await replay.future, same(event));
      expect(event.flagsChanged, originalKeys);
    });
  }

  for (final cacheCase in ['missing', 'invalid', 'mismatched', 'late']) {
    test('$cacheCase cache cannot claim notification', () async {
      final disk = Completer<FlagsData?>();
      final events = <FlagsClientEvent>[];
      final store = _Store(() async {
        if (cacheCase == 'invalid') throw FormatException('invalid cache');
        if (cacheCase == 'mismatched') return _cached(subject: 'someone-else');
        if (cacheCase == 'late') return await disk.future;
        return null;
      });
      final flags = await _owner(
          callback: events.add,
          store: store,
          request: (_) async => _response({'network-only': true}));
      await flags.sharedClient().initialize(_context);
      if (cacheCase == 'late') disk.complete(_cached());
      await Future<void>.delayed(Duration.zero);
      expect(events.single.flagsChanged, ['network-only']);
    });
  }

  final failedLoads = <String, Future<http.Response> Function()>{
    'transport failure': () async => throw StateError('offline'),
    'HTTP failure': () async => http.Response('{}', 503),
    'malformed JSON': () async => http.Response('{', 200),
    'missing configuration': () async => http.Response('{}', 200),
    'missing flags': () async =>
        http.Response('{"data":{"attributes":{}}}', 200),
    'invalid flags type': () async =>
        http.Response('{"data":{"attributes":{"flags":[]}}}', 200),
  };
  for (final failure in failedLoads.entries) {
    test('${failure.key} does not consume first signal; valid empty load does',
        () async {
      final events = <FlagsClientEvent>[];
      var attempts = 0;
      final flags = await _owner(
          callback: events.add,
          request: (_) =>
              ++attempts == 1 ? failure.value() : Future.value(_response({})));
      final client = flags.sharedClient();
      await client.initialize(_context);
      expect(events, isEmpty);
      expect(
          client
              .getBooleanDetails(key: 'checkout.enabled', defaultValue: false)
              .error,
          FlagEvaluationError.providerNotReady);
      await client.initialize(_context);
      expect(attempts, 2);
      expect(events, hasLength(1));
      expect(events.single.flagsChanged, isEmpty);
      expect(
          client
              .getBooleanDetails(key: 'checkout.enabled', defaultValue: false)
              .error,
          FlagEvaluationError.flagNotFound);
    });
  }

  test('retained event contains all accepted keys and no rejected entries',
      () async {
    final events = <FlagsClientEvent>[];
    final flags = await _owner(
        callback: events.add,
        request: (_) async => http.Response(
            jsonEncode({
              'data': {
                'attributes': {
                  'flags': {
                    'first': _flag(true),
                    'invalid': null,
                    'second': _flag(false),
                  }
                }
              }
            }),
            200));
    await flags.sharedClient().initialize(_context);
    expect(events, hasLength(1));
    expect(events.single.flagsChanged, unorderedEquals(['first', 'second']));
  });

  test('late replay does not fetch or access persistence', () async {
    var requests = 0;
    var reads = 0;
    var writes = 0;
    final events = <FlagsClientEvent>[];
    final store = _Store(() async {
      reads++;
      return null;
    })
      ..save = (_) async {
        writes++;
      };
    final flags = await _owner(
        callback: events.add,
        store: store,
        request: (_) async {
          requests++;
          return _response();
        });
    final client = flags.sharedClient();
    await client.initialize(_context);
    expect((requests, reads, writes), (1, 1, 1));
    final first = events.single;
    client.onFirstFlags(events.add);
    expect(events, hasLength(1));
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(2));
    expect(events.last, same(first));
    expect((requests, reads, writes), (1, 1, 1));
  });

  for (final failUpdate in [false, true]) {
    test(
        'late replay keeps original keys after ${failUpdate ? "failed" : "successful"} context update',
        () async {
      var requests = 0;
      final contexts = <String>[];
      final events = <FlagsClientEvent>[];
      final flags = await _owner(
          callback: events.add,
          request: (request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            contexts.add(body['data']['attributes']['subject']['targeting_key']
                as String);
            if (++requests == 1) return _response({'original': true});
            if (failUpdate) throw StateError('offline');
            return _response({'current': false});
          });
      final client = flags.sharedClient();
      await client.initialize(_context);
      final first = events.single;
      await client.initialize(
          const FlagsEvaluationContext(targetingKey: 'updated-user'));
      final delivered = Completer<FlagsClientEvent>();
      FlagDetails<bool>? current;
      client.onFirstFlags((event) {
        current = client.getBooleanDetails(key: 'current', defaultValue: true);
        delivered.complete(event);
      });
      expect(delivered.isCompleted, isFalse);
      expect(await delivered.future, same(first));
      expect(first.flagsChanged, ['original']);
      expect(contexts, ['example-user', 'updated-user']);
      expect(current!.value, failUpdate);
      expect(current!.error,
          failUpdate ? FlagEvaluationError.providerNotReady : null);
      expect(events, hasLength(1));
    });
  }

  test('superseded network is rejected before claiming first notification',
      () async {
    final oldResponse = Completer<http.Response>();
    final events = <FlagsClientEvent>[];
    var requests = 0;
    final flags = await _owner(
        callback: events.add,
        request: (_) => ++requests == 1
            ? oldResponse.future
            : Future.value(_response({'current': true})));
    final client = flags.sharedClient();
    final old = client.initialize(_context);
    await client
        .initialize(const FlagsEvaluationContext(targetingKey: 'new-user'));
    oldResponse.complete(_response({'obsolete': true}));
    await old;
    expect(events.single.flagsChanged, ['current']);
  });

  test('callback is consumed before reentrant reset and initialization',
      () async {
    var calls = 0;
    late DatadogFlagsClient client;
    Future<void>? refresh;
    final flags = await _owner(callback: (_) {
      calls++;
      refresh = client.reset().then((_) => client
          .initialize(const FlagsEvaluationContext(targetingKey: 'new-user')));
    });
    client = flags.sharedClient();
    await client.initialize(_context);
    await refresh;
    expect(calls, 1);
    final details =
        client.getBooleanDetails(key: 'checkout.enabled', defaultValue: false);
    expect(details.value, isTrue);
    expect(details.error, isNull);
  });

  test(
      'synchronous callback exception does not clear assignments or fail initialization',
      () async {
    var calls = 0;
    final flags = await _owner(callback: (_) {
      calls++;
      throw StateError('app');
    });
    final client = flags.sharedClient();
    await client.initialize(_context);
    expect(
        client
            .getBooleanDetails(key: 'checkout.enabled', defaultValue: false)
            .value,
        isTrue);
    await client.initialize(_context);
    expect(calls, 1);
  });

  test('each client independently retains its first event', () async {
    final events = <FlagsClientEvent>[];
    final flags = await _owner(callback: events.add);
    await flags.sharedClient().initialize(_context);
    await flags.sharedClient().initialize(_context);
    flags.sharedClient(name: 'other').onFirstFlags(events.add);
    await flags.sharedClient(name: 'other').initialize(_context);
    expect(events, hasLength(2));
  });

  test('notification does not wait for persistence or emit telemetry',
      () async {
    final saved = Completer<void>();
    final delivered = Completer<void>();
    final requests = <Uri>[];
    final store = _Store(() async => null)..save = (_) => saved.future;
    final flags = await _owner(
        store: store,
        callback: (_) => delivered.complete(),
        request: (request) async {
          requests.add(request.url);
          return _response();
        });
    var completed = false;
    final init =
        flags.sharedClient().initialize(_context).then((_) => completed = true);
    await delivered.future;
    expect(completed, isFalse);
    saved.complete();
    await init;
    await flags.disable();
    expect(requests, hasLength(1));
  });

  test(
      'timeout does not fabricate an event but a late accepted result can notify',
      () async {
    final response = Completer<http.Response>();
    final delivered = Completer<void>();
    final flags = await _owner(
        timeout: const Duration(milliseconds: 1),
        callback: (_) => delivered.complete(),
        request: (_) => response.future);
    await expectLater(flags.sharedClient().initialize(_context),
        throwsA(isA<FlagsInitializationTimeoutException>()));
    expect(delivered.isCompleted, isFalse);
    response.complete(_response());
    await delivered.future;
  });
}
