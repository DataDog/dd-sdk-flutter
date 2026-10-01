// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/assignment.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const context = FlagsEvaluationContext(targetingKey: 'alice');
const otherContext = FlagsEvaluationContext(targetingKey: 'bob');

Map<String, Object?> assignment(bool value) => {
      'allocationKey': 'allocation',
      'variationKey': 'variant',
      'variationType': 'boolean',
      'variationValue': value,
      'reason': 'TARGETING_MATCH',
      'doLog': true,
    };

http.Response response([Map<String, bool> flags = const {'network': true}]) =>
    http.Response(
        jsonEncode({
          'data': {
            'attributes': {
              'flags':
                  flags.map((key, value) => MapEntry(key, assignment(value)))
            }
          }
        }),
        200);

FlagsData data(
        [Map<String, bool> flags = const {'cached': true},
        FlagsEvaluationContext evaluationContext = context]) =>
    FlagsData(
      flags: flags.map((key, value) =>
          MapEntry(key, FlagAssignment.fromJson(assignment(value)))),
      context: evaluationContext,
      date: DateTime.utc(2026),
    );

class Store implements DatadogFlagsStore {
  Future<FlagsData?> Function() readData;
  Future<void> Function(FlagsData)? writeData;
  Store(this.readData);
  @override
  Future<FlagsData?> read(String name) async {
    final value = await readData();
    return value;
  }

  @override
  Future<void> write(String name, FlagsData value) async =>
      writeData?.call(value);
  @override
  Future<void> delete(String name) async {}
}

Future<DatadogFlags> owner({
  OnFirstFlags? callback,
  Store? store,
  Future<http.Response> Function(http.Request)? request,
  Duration? timeout,
  DateTime Function()? clock,
}) async {
  final flags = DatadogFlags();
  await flags.enable(
      configuration: DatadogFlagsConfiguration(
    datadogConfig: const DatadogFlagsConfig(
        clientToken: 'client-token', env: 'test', site: DatadogFlagsSite.us1),
    httpClient: MockClient(request ?? (_) async => response()),
    store: store,
    onFirstFlags: callback,
    initializationTimeout: timeout,
    dateProvider: clock ?? DateTime.now,
  ));
  addTearDown(flags.disable);
  return flags;
}

void main() {
  test('configuration hook sees usable default client before network completes',
      () async {
    final network = Completer<http.Response>();
    final delivered = Completer<void>();
    final events = <FlagsClientEvent>[];
    final flags = await owner(
      store: Store(() async => data()),
      request: (_) => network.future,
      callback: (client, event) {
        try {
          expect(client.name, 'default');
          expect(
              client
                  .getBooleanDetails(key: 'cached', defaultValue: false)
                  .value,
              isTrue);
          events.add(event);
          delivered.complete();
        } catch (error, stack) {
          delivered.completeError(error, stack);
        }
      },
    );
    final client = flags.sharedClient();
    var completed = false;
    final initialization =
        client.initialize(context).then((_) => completed = true);
    await delivered.future;
    expect(completed, isFalse);
    final event = events.single;
    expect(event.type, FlagsClientEventType.configurationChanged);
    expect(event.type.code, 'CONFIGURATION_CHANGED');
    expect(event.providerName, 'Datadog');
    expect(event.flagsChanged, ['cached']);
    expect(event.metadata, isEmpty);
    expect(event.message, isNull);
    expect(event.errorCode, isNull);
    expect(() => event.flagsChanged!.add('x'), throwsUnsupportedError);
    expect(() => event.metadata['x'] = true, throwsUnsupportedError);
    network.complete(response());
    await initialization;
    expect(events, hasLength(1));
    expect(event.flagsChanged, ['cached']);
  });

  for (final cached in [false, true]) {
    test('accepted empty ${cached ? 'cache' : 'network'} fires with empty keys',
        () async {
      final events = <FlagsClientEvent>[];
      final flags = await owner(
          store: cached ? Store(() async => data({})) : null,
          callback: (_, event) => events.add(event),
          request: (_) async => response({}));
      await flags.sharedClient().initialize(context);
      expect(events.single.flagsChanged, isEmpty);
    });
  }

  for (final cacheCase in ['missing', 'invalid', 'mismatched', 'late']) {
    test('$cacheCase disk does not claim first installation', () async {
      final disk = Completer<FlagsData?>();
      final events = <FlagsClientEvent>[];
      final store = Store(() {
        if (cacheCase == 'invalid') {
          return Future.error(FormatException('invalid'));
        }
        if (cacheCase == 'mismatched') {
          return Future.value(data({'wrong': true}, otherContext));
        }
        if (cacheCase == 'late') return disk.future;
        return Future.value(null);
      });
      final flags =
          await owner(store: store, callback: (_, event) => events.add(event));
      await flags.sharedClient().initialize(context);
      if (cacheCase == 'late') disk.complete(data());
      await Future<void>.delayed(Duration.zero);
      expect(events.single.flagsChanged, ['network']);
      expect(
          flags
              .sharedClient()
              .getBooleanDetails(key: 'cached', defaultValue: false)
              .error,
          FlagEvaluationError.flagNotFound);
    });
  }

  test('failed disk and network never fabricate an installation', () async {
    var calls = 0;
    final flags = await owner(
        store: Store(() async => throw FormatException('bad cache')),
        request: (_) async => throw StateError('offline'),
        callback: (_, __) => calls++);
    await flags.sharedClient().initialize(context);
    expect(calls, 0);
  });

  test('named override replaces fallback and existing lookups ignore hooks',
      () async {
    final seen = <String>[];
    final flags =
        await owner(callback: (client, _) => seen.add('config:${client.name}'));
    final defaultClient =
        flags.sharedClient(onFirstFlags: (_, __) => seen.add('late-default'));
    final named = flags.sharedClient(
        name: 'named',
        onFirstFlags: (client, _) => seen.add('override:${client.name}'));
    expect(
        identical(
            named,
            flags.sharedClient(
                name: 'named', onFirstFlags: (_, __) => seen.add('late'))),
        isTrue);
    await defaultClient.initialize(context);
    await named.initialize(context);
    await flags.sharedClient(name: 'inherited').initialize(context);
    await named.reset();
    await named.initialize(otherContext);
    expect(seen, ['config:default', 'override:named', 'config:inherited']);
  });

  test('cache callback is registered before synchronous store completion',
      () async {
    final events = <FlagsClientEvent>[];
    final flags = await owner(
        store: Store(() => Future.value(data())),
        callback: (_, event) => events.add(event));
    await flags.sharedClient().initialize(context);
    expect(events.single.flagsChanged, ['cached']);
  });

  test(
      'reentrant reset and initialization do not rearm or overwrite newer context',
      () async {
    var calls = 0;
    final reentered = Completer<void>();
    final oldNetwork = Completer<http.Response>();
    var requests = 0;
    final flags = await owner(
        store: Store(() async => data()),
        request: (_) => ++requests == 1
            ? oldNetwork.future
            : Future.value(response({'new': true})),
        callback: (client, _) async {
          calls++;
          await client.reset();
          await client.initialize(otherContext);
          reentered.complete();
        });
    final initial = flags.sharedClient().initialize(context);
    await reentered.future;
    oldNetwork.complete(response({'old': true}));
    await initial;
    expect(calls, 1);
    expect(
        flags
            .sharedClient()
            .getBooleanDetails(key: 'new', defaultValue: false)
            .value,
        isTrue);
    expect(
        flags
            .sharedClient()
            .getBooleanDetails(key: 'old', defaultValue: false)
            .error,
        FlagEvaluationError.flagNotFound);
  });

  test(
      'superseded disk and network cannot claim or overwrite current installation',
      () async {
    final oldDisk = Completer<FlagsData?>();
    var reads = 0;
    final events = <FlagsClientEvent>[];
    final flags = await owner(
        store: Store(() => ++reads == 1 ? oldDisk.future : Future.value(null)),
        callback: (_, event) => events.add(event));
    final client = flags.sharedClient();
    final old = client.initialize(context);
    await client.initialize(otherContext);
    oldDisk.complete(data());
    await old;
    expect(events.single.flagsChanged, ['network']);
  });

  test('superseded network cannot claim first installation', () async {
    final oldResponse = Completer<http.Response>();
    var requests = 0;
    final events = <FlagsClientEvent>[];
    final flags = await owner(
        request: (_) => ++requests == 1
            ? oldResponse.future
            : Future.value(response({'new': true})),
        callback: (_, event) => events.add(event));
    final client = flags.sharedClient();
    final old = client.initialize(context);
    await client.initialize(otherContext);
    oldResponse.complete(response({'old': true}));
    await old;
    expect(events.single.flagsChanged, ['new']);
  });

  test('accepted event survives context change queued before its delivery',
      () async {
    final events = <FlagsClientEvent>[];
    late DatadogFlagsClient client;
    var first = true;
    Future<void>? refresh;
    final flags = await owner(
        callback: (_, event) => events.add(event),
        clock: () {
          if (first) {
            first = false;
            scheduleMicrotask(() {
              refresh = client.initialize(otherContext);
            });
          }
          return DateTime.utc(2026);
        });
    client = flags.sharedClient();
    await client.initialize(context);
    await refresh;
    expect(events.single.flagsChanged, ['network']);
  });

  test('shutdown before queued delivery suppresses accepted hook', () async {
    var calls = 0;
    late DatadogFlagsClient client;
    final flags = await owner(
        callback: (_, __) => calls++,
        clock: () {
          scheduleMicrotask(() => unawaited(client.shutdown()));
          return DateTime.utc(2026);
        });
    client = flags.sharedClient();
    await client.initialize(context);
    expect(calls, 0);
  });

  test('shutdown before installation suppresses late completion', () async {
    var calls = 0;
    final network = Completer<http.Response>();
    final flags = await owner(
        request: (_) => network.future, callback: (_, __) => calls++);
    final client = flags.sharedClient();
    final init = client.initialize(context);
    await client.shutdown();
    network.complete(response());
    await init;
    expect(calls, 0);
    expect(client.getBooleanDetails(key: 'network', defaultValue: false).error,
        FlagEvaluationError.providerNotReady);
  });

  test('callback may shut down reentrantly without deadlock or repeat',
      () async {
    var calls = 0;
    final stopped = Completer<void>();
    final flags = await owner(callback: (client, _) async {
      calls++;
      await client.shutdown();
      stopped.complete();
    });
    await flags.sharedClient().initialize(context);
    await stopped.future;
    expect(calls, 1);
  });

  for (final asynchronous in [false, true]) {
    test(
        '${asynchronous ? 'async' : 'sync'} callback failure does not fail initialization',
        () async {
      var calls = 0;
      final flags = await owner(callback: (_, __) {
        calls++;
        if (asynchronous) return Future<void>.error(StateError('callback'));
        throw StateError('callback');
      });
      final client = flags.sharedClient();
      await client.initialize(context);
      await Future<void>.delayed(Duration.zero);
      expect(
          client.getBooleanDetails(key: 'network', defaultValue: false).reason,
          'TARGETING_MATCH');
      await client.initialize(context);
      expect(calls, 1);
    });
  }

  test('timeout does not claim hook and late successful response can deliver',
      () async {
    final network = Completer<http.Response>();
    final delivered = Completer<void>();
    final flags = await owner(
        timeout: const Duration(milliseconds: 1),
        request: (_) => network.future,
        callback: (_, __) => delivered.complete());
    await expectLater(flags.sharedClient().initialize(context),
        throwsA(isA<FlagsInitializationTimeoutException>()));
    expect(delivered.isCompleted, isFalse);
    network.complete(response());
    await delivered.future;
  });

  test(
      'delivery does not wait for persistence and collecting keys emits no telemetry',
      () async {
    final persistence = Completer<void>();
    final delivered = Completer<void>();
    final requests = <Uri>[];
    final store = Store(() async => null)
      ..writeData = (_) => persistence.future;
    final flags = await owner(
        store: store,
        callback: (_, __) => delivered.complete(),
        request: (request) async {
          requests.add(request.url);
          return response();
        });
    var completed = false;
    final init =
        flags.sharedClient().initialize(context).then((_) => completed = true);
    await delivered.future;
    expect(completed, isFalse);
    persistence.complete();
    await init;
    await flags.disable();
    expect(requests, hasLength(1));
  });

  test('new client lifetime gets its own hook', () async {
    var calls = 0;
    final flags = await owner(callback: (_, __) => calls++);
    final client = flags.sharedClient();
    await client.initialize(context);
    await flags.disable();
    final replacement = await owner(callback: (_, __) => calls++);
    await replacement.sharedClient().initialize(context);
    expect(calls, 2);
  });

  test('event snapshots and validates flat metadata', () {
    final keys = ['a'];
    final metadata = <String, Object>{
      'enabled': true,
      'count': 1,
      'ratio': 1.2,
      'label': 'x'
    };
    final event = FlagsClientEvent(
        type: FlagsClientEventType.configurationChanged,
        providerName: 'Datadog',
        flagsChanged: keys,
        metadata: metadata);
    keys.clear();
    metadata.clear();
    expect(event.flagsChanged, ['a']);
    expect(event.metadata, hasLength(4));
    expect(
        () => FlagsClientEvent(
            type: FlagsClientEventType.error,
            providerName: 'Datadog',
            metadata: {'nested': {}}),
        throwsArgumentError);
  });
}
