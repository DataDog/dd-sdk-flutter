// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/assignment.dart';
import 'package:datadog_flags/src/flag_assignments_fetcher.dart';
import 'package:datadog_flags/src/flags_repository.dart';
import 'package:datadog_flags/src/flags_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('uses a five-second initialization timeout by default', () {
    expect(
      const DatadogFlagsConfiguration().initializationTimeout,
      const Duration(seconds: 5),
    );
    expect(
      const DatadogFlagsConfiguration(
        initializationTimeout: Duration(milliseconds: 2500),
      ).initializationTimeout,
      const Duration(milliseconds: 2500),
    );
  });

  test('accepts disabled initialization timeout values', () {
    expect(
      const DatadogFlagsConfiguration(
        initializationTimeout: null,
      ).initializationTimeout,
      isNull,
    );
    expect(
      const DatadogFlagsConfiguration(
        initializationTimeout: Duration.zero,
      ).initializationTimeout,
      Duration.zero,
    );
    expect(
      const DatadogFlagsConfiguration(
        initializationTimeout: Duration(milliseconds: -1),
      ).initializationTimeout,
      const Duration(milliseconds: -1),
    );
  });

  test('does not schedule a timer for disabled timeout values', () async {
    for (final timeout in <Duration?>[
      null,
      Duration.zero,
      const Duration(milliseconds: -1),
    ]) {
      var scheduleCount = 0;
      final httpClient = MockClient((_) async {
        return http.Response(jsonEncode(_assignmentsResponse()), 200);
      });
      final configuration = _configuration(
        httpClient: httpClient,
        initializationTimeout: timeout,
      );
      final repository = FlagsRepository(
        clientName: DatadogFlags.defaultClientName,
        fetcher: FlagAssignmentsFetcher(
          datadogConfig: _datadogConfig,
          configuration: configuration,
          httpClient: httpClient,
        ),
        dateProvider: DateTime.now,
        initializationTimeout: timeout,
        scheduleInitializationTimeout: (_, __) {
          scheduleCount += 1;
          return _TestTimer();
        },
      );

      await repository.initialize(_context);

      expect(scheduleCount, 0, reason: 'Unexpected timer for $timeout');
      expect(repository.flagAssignment('show-paywall'), isNotNull);
    }
  });

  test(
    'times out while downloading the response body and recovers later',
    () async {
      final httpClient = _ControlledResponseBodyClient();
      final datadogFlags = DatadogFlags();
      addTearDown(() async {
        httpClient.close();
        await datadogFlags.disable();
      });
      await datadogFlags.enable(
        configuration: _configuration(
          httpClient: httpClient,
          initializationTimeout: const Duration(milliseconds: 5),
        ),
      );
      final client = datadogFlags.sharedClient();

      final initialization = client.initialize(_context);
      await httpClient.requestStarted.future;
      await initialization.timeout(const Duration(seconds: 1));

      expect(httpClient.bodyCompleted, isFalse);
      expect(
        client
            .getBooleanDetails(key: 'show-paywall', defaultValue: false)
            .error,
        FlagEvaluationError.providerNotReady,
      );

      await httpClient.completeBody(_assignmentsResponse());
      await _waitUntil(() {
        return client
                .getBooleanDetails(key: 'show-paywall', defaultValue: false)
                .error ==
            null;
      });
      expect(
        client
            .getBooleanDetails(key: 'show-paywall', defaultValue: false)
            .value,
        isTrue,
      );
    },
  );

  test(
    'uses matching stored assignments when initialization times out',
    () async {
      final store = InMemoryDatadogFlagsStore();
      await store.write(
        DatadogFlags.defaultClientName,
        _storedAssignments(_context, value: true),
      );
      final httpClient = _ControlledResponseBodyClient();
      final datadogFlags = DatadogFlags();
      addTearDown(() async {
        httpClient.close();
        await datadogFlags.disable();
      });
      await datadogFlags.enable(
        configuration: _configuration(
          httpClient: httpClient,
          store: store,
          initializationTimeout: const Duration(milliseconds: 5),
        ),
      );
      final client = datadogFlags.sharedClient();

      await client.initialize(_context).timeout(const Duration(seconds: 1));

      expect(
        client
            .getBooleanDetails(key: 'show-paywall', defaultValue: false)
            .value,
        isTrue,
      );

      await httpClient.completeBody(_assignmentsResponse(booleanValue: false));
      await _waitUntil(() {
        return client
                .getBooleanDetails(key: 'show-paywall', defaultValue: true)
                .value ==
            false;
      });
    },
  );

  test('includes assignment storage before publishing ready state', () async {
    final store = _DelayedWriteStore();
    final datadogFlags = DatadogFlags();
    addTearDown(() async {
      if (!store.allowWrite.isCompleted) {
        store.allowWrite.complete();
      }
      await datadogFlags.disable();
    });
    await datadogFlags.enable(
      configuration: _configuration(
        httpClient: MockClient((_) async {
          return http.Response(jsonEncode(_assignmentsResponse()), 200);
        }),
        store: store,
        initializationTimeout: const Duration(milliseconds: 5),
      ),
    );
    final client = datadogFlags.sharedClient();

    final initialization = client.initialize(_context);
    await store.writeStarted.future;
    await initialization.timeout(const Duration(seconds: 1));

    expect(
      client.getBooleanDetails(key: 'show-paywall', defaultValue: false).error,
      FlagEvaluationError.providerNotReady,
    );

    store.allowWrite.complete();
    await _waitUntil(() {
      return client
              .getBooleanDetails(key: 'show-paywall', defaultValue: false)
              .error ==
          null;
    });
  });

  test(
    'applies the initialization timeout only to the first context',
    () async {
      final responses = <Completer<http.Response>>[];
      final datadogFlags = DatadogFlags();
      addTearDown(datadogFlags.disable);
      await datadogFlags.enable(
        configuration: _configuration(
          httpClient: MockClient((_) {
            final response = Completer<http.Response>();
            responses.add(response);
            return response.future;
          }),
          initializationTimeout: const Duration(milliseconds: 5),
        ),
      );
      final client = datadogFlags.sharedClient();

      await client.initialize(_context).timeout(const Duration(seconds: 1));

      var secondCompleted = false;
      final second = client
          .initialize(const FlagsEvaluationContext(targetingKey: 'user-second'))
          .whenComplete(() => secondCompleted = true);
      await _waitUntil(() => responses.length == 2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(secondCompleted, isFalse);

      responses[1].complete(
        http.Response(
          jsonEncode(_assignmentsResponse(booleanValue: false)),
          200,
        ),
      );
      await second.timeout(const Duration(seconds: 1));
      responses[0].complete(
        http.Response(jsonEncode(_assignmentsResponse()), 200),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        client.getBooleanDetails(key: 'show-paywall', defaultValue: true).value,
        isFalse,
      );
    },
  );

  test(
    'later context supersedes initialization before timeout',
    () async {
      final responses = <Completer<http.Response>>[];
      void Function()? timeoutAction;
      var scheduleCount = 0;
      final httpClient = MockClient((_) {
        final response = Completer<http.Response>();
        responses.add(response);
        return response.future;
      });
      final configuration = _configuration(
        httpClient: httpClient,
        initializationTimeout: const Duration(seconds: 5),
      );
      final repository = FlagsRepository(
        clientName: DatadogFlags.defaultClientName,
        fetcher: FlagAssignmentsFetcher(
          datadogConfig: _datadogConfig,
          configuration: configuration,
          httpClient: httpClient,
        ),
        dateProvider: DateTime.now,
        initializationTimeout: configuration.initializationTimeout,
        scheduleInitializationTimeout: (_, action) {
          scheduleCount += 1;
          timeoutAction = action;
          return _TestTimer();
        },
      );

      final first = repository.initialize(_context);
      await _waitUntil(() => responses.length == 1);

      var secondCompleted = false;
      const secondContext = FlagsEvaluationContext(
        targetingKey: 'user-second',
      );
      final second = repository
          .initialize(secondContext)
          .whenComplete(() => secondCompleted = true);
      await _waitUntil(() => responses.length == 2);

      expect(scheduleCount, 1);
      timeoutAction!();
      await first.timeout(const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);
      expect(secondCompleted, isFalse);
      expect(repository.context, isNull);

      responses[1].complete(
        http.Response(
          jsonEncode(_assignmentsResponse(booleanValue: false)),
          200,
        ),
      );
      await second.timeout(const Duration(seconds: 1));
      expect(repository.context, secondContext);
      expect(
        repository.flagAssignment('show-paywall')?.variationValue,
        isFalse,
      );

      responses[0].complete(
        http.Response(jsonEncode(_assignmentsResponse()), 200),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repository.context, secondContext);
      expect(
        repository.flagAssignment('show-paywall')?.variationValue,
        isFalse,
      );
    },
  );

  test('keeps the deadline active through response JSON decoding', () async {
    void Function()? timeoutAction;
    final fetcher = FlagAssignmentsFetcher(
      datadogConfig: _datadogConfig,
      configuration: _configuration(
        httpClient: MockClient((_) async {
          return http.Response('{}', 200);
        }),
      ),
      httpClient: MockClient((_) async {
        return http.Response('{}', 200);
      }),
      responseDecoder: (_) {
        timeoutAction!();
        return PrecomputedAssignments(
          flags: {'show-paywall': _assignment(value: true)},
        );
      },
    );
    final repository = FlagsRepository(
      clientName: DatadogFlags.defaultClientName,
      fetcher: fetcher,
      dateProvider: DateTime.now,
      initializationTimeout: const Duration(seconds: 5),
      scheduleInitializationTimeout: (_, action) {
        timeoutAction = action;
        return _TestTimer();
      },
    );

    await repository.initialize(_context);

    expect(repository.flagAssignment('show-paywall'), isNull);
    await _waitUntil(() => repository.flagAssignment('show-paywall') != null);
  });

  test('counts synchronous request encoding against the deadline', () async {
    final response = Completer<http.Response>();
    final httpClient = MockClient((_) => response.future);
    final configuration = _configuration(
      httpClient: httpClient,
      initializationTimeout: const Duration(milliseconds: 1),
    );
    final repository = FlagsRepository(
      clientName: DatadogFlags.defaultClientName,
      fetcher: FlagAssignmentsFetcher(
        datadogConfig: _datadogConfig,
        configuration: configuration,
        httpClient: httpClient,
      ),
      dateProvider: DateTime.now,
      initializationTimeout: configuration.initializationTimeout,
      scheduleInitializationTimeout: (_, __) => _TestTimer(),
    );
    final context = FlagsEvaluationContext(
      targetingKey: 'user-123',
      attributes: {'slow': _SlowIterable(const Duration(milliseconds: 10))},
    );

    await repository.initialize(context).timeout(const Duration(seconds: 1));

    expect(repository.flagAssignment('show-paywall'), isNull);
    response.complete(http.Response(jsonEncode(_assignmentsResponse()), 200));
    await _waitUntil(() => repository.flagAssignment('show-paywall') != null);
  });
}

const _context = FlagsEvaluationContext(targetingKey: 'user-123');

const _datadogConfig = DatadogFlagsConfig(
  clientToken: 'client-token',
  env: 'staging',
  site: DatadogFlagsSite.us1,
);

DatadogFlagsConfiguration _configuration({
  required http.Client httpClient,
  Duration? initializationTimeout =
      DatadogFlagsConfiguration.defaultInitializationTimeout,
  DatadogFlagsStore? store,
}) {
  return DatadogFlagsConfiguration(
    datadogConfig: _datadogConfig,
    trackExposures: false,
    trackEvaluations: false,
    httpClient: httpClient,
    initializationTimeout: initializationTimeout,
    store: store,
  );
}

Map<String, Object?> _assignmentsResponse({bool booleanValue = true}) {
  return {
    'data': {
      'attributes': {
        'flags': {'show-paywall': _assignmentJson(value: booleanValue)},
      },
    },
  };
}

FlagAssignment _assignment({required bool value}) {
  return FlagAssignment.fromJson(_assignmentJson(value: value));
}

Map<String, Object?> _assignmentJson({required bool value}) {
  return {
    'allocationKey': 'allocation-a',
    'variationKey': value ? 'enabled' : 'disabled',
    'variationType': 'boolean',
    'variationValue': value,
    'reason': 'TARGETING_MATCH',
    'doLog': true,
  };
}

FlagsData _storedAssignments(
  FlagsEvaluationContext context, {
  required bool value,
}) {
  return FlagsData.fromJson({
    'flags': {'show-paywall': _assignmentJson(value: value)},
    'context': context.toJson(),
    'date': DateTime.utc(2026, 9, 11).toIso8601String(),
  });
}

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _ControlledResponseBodyClient extends http.BaseClient {
  final StreamController<List<int>> _body = StreamController<List<int>>();
  final Completer<void> requestStarted = Completer<void>();
  bool bodyCompleted = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!requestStarted.isCompleted) {
      requestStarted.complete();
    }
    return http.StreamedResponse(_body.stream, 200);
  }

  Future<void> completeBody(Map<String, Object?> body) async {
    bodyCompleted = true;
    _body.add(utf8.encode(jsonEncode(body)));
    await _body.close();
  }
}

class _DelayedWriteStore implements DatadogFlagsStore {
  final InMemoryDatadogFlagsStore _delegate = InMemoryDatadogFlagsStore();
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> allowWrite = Completer<void>();

  @override
  Future<FlagsData?> read(String clientName) {
    return _delegate.read(clientName);
  }

  @override
  Future<void> write(String clientName, FlagsData data) async {
    if (!writeStarted.isCompleted) {
      writeStarted.complete();
    }
    await allowWrite.future;
    await _delegate.write(clientName, data);
  }

  @override
  Future<void> delete(String clientName) {
    return _delegate.delete(clientName);
  }
}

class _TestTimer implements Timer {
  var _isActive = true;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => 0;

  @override
  void cancel() {
    _isActive = false;
  }
}

class _SlowIterable extends Iterable<Object?> {
  final Duration delay;

  _SlowIterable(this.delay);

  @override
  Iterator<Object?> get iterator {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < delay) {}
    return <Object?>[true].iterator;
  }
}
