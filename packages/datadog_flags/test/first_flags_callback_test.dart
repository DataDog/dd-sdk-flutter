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
      final events = <FlagsClientEvent>[];
      final flags = await _owner(
          callback: events.add,
          store: fromCache ? _Store(() async => _cached(empty: true)) : null,
          request: (_) async => _response({}));
      await flags.sharedClient().initialize(_context);
      expect(events.single.type, FlagsClientEventType.configurationChanged);
      expect(events.single.flagsChanged, isEmpty);
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

  test('failed initialization without installation does not notify', () async {
    final events = <FlagsClientEvent>[];
    final flags = await _owner(
        callback: events.add,
        store: _Store(() async => throw FormatException('invalid cache')),
        request: (_) async => throw StateError('offline'));
    await flags.sharedClient().initialize(_context);
    expect(events, isEmpty);
  });

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
