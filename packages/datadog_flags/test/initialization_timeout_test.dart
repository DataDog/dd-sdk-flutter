// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
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
      final repository = _repository(
        httpClient: httpClient,
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

  test('cancels the initialization timer when initialization finishes',
      () async {
    final timers = <_TestTimer>[];
    final httpClient = MockClient((_) async {
      return http.Response(jsonEncode(_assignmentsResponse()), 200);
    });
    final repository = _repository(
      httpClient: httpClient,
      initializationTimeout: const Duration(seconds: 30),
      scheduleInitializationTimeout: (_, __) {
        final timer = _TestTimer();
        timers.add(timer);
        return timer;
      },
    );

    await repository.initialize(_context).timeout(const Duration(seconds: 1));

    expect(repository.flagAssignment('show-paywall'), isNotNull);
    expect(timers.single.cancelCount, 1);
  });

  test(
    'throws at the total budget while the network response is loading',
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
      await expectLater(
        initialization.timeout(const Duration(seconds: 1)),
        _throwsInitializationTimeout(const Duration(milliseconds: 5)),
      );

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
    'throws at the total budget while persistent assignments are loading',
    () async {
      const budget = Duration(seconds: 5);
      void Function()? timeoutAction;
      Duration? scheduledTimeout;
      final timer = _TestTimer();
      final store = _DelayedReadStore();
      addTearDown(() {
        if (!store.allowRead.isCompleted) {
          store.allowRead.complete();
        }
      });
      final httpClient = MockClient((_) async {
        return http.Response(jsonEncode(_assignmentsResponse()), 200);
      });
      final repository = _repository(
        httpClient: httpClient,
        store: store,
        initializationTimeout: budget,
        scheduleInitializationTimeout: (duration, action) {
          scheduledTimeout = duration;
          timeoutAction = action;
          return timer;
        },
      );

      final initialization = repository.initialize(_context);
      await store.readStarted.future;
      expect(scheduledTimeout, budget);
      timeoutAction!();
      await expectLater(
        initialization.timeout(const Duration(seconds: 1)),
        _throwsInitializationTimeout(budget),
      );

      expect(repository.flagAssignment('show-paywall'), isNull);
      expect(timer.cancelCount, 1);

      store.allowRead.complete();
      await _waitUntil(() => repository.flagAssignment('show-paywall') != null);
    },
  );

  test(
    'publishes matching stored assignments before an overdue timer runs',
    () async {
      final response = Completer<http.Response>();
      addTearDown(() {
        if (!response.isCompleted) {
          response.complete(
            http.Response(jsonEncode(_assignmentsResponse()), 200),
          );
        }
      });
      final store = _BlockingReadStore(
        data: _storedAssignments(_context, value: true),
        delay: const Duration(milliseconds: 10),
      );
      final httpClient = MockClient((_) => response.future);
      final repository = _repository(
        httpClient: httpClient,
        store: store,
        initializationTimeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        repository.initialize(_context).timeout(const Duration(seconds: 1)),
        _throwsInitializationTimeout(const Duration(milliseconds: 1)),
      );

      expect(
        repository.flagAssignment('show-paywall')?.variationValue,
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

      await expectLater(
        client.initialize(_context).timeout(const Duration(seconds: 1)),
        _throwsInitializationTimeout(const Duration(milliseconds: 5)),
      );

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

  test('publishes assignments while persistent storage remains in progress',
      () async {
    final store = _DelayedWriteStore();
    addTearDown(() {
      if (!store.allowWrite.isCompleted) {
        store.allowWrite.complete();
      }
    });
    final httpClient = MockClient((_) async {
      return http.Response(jsonEncode(_assignmentsResponse()), 200);
    });
    final repository = _repository(
      httpClient: httpClient,
      store: store,
      initializationTimeout: null,
    );

    var initializationCompleted = false;
    final initialization = repository
        .initialize(_context)
        .whenComplete(() => initializationCompleted = true);
    await store.writeStarted.future;

    expect(
      repository.flagAssignment('show-paywall')?.variationValue,
      isTrue,
    );
    expect(initializationCompleted, isFalse);

    store.allowWrite.complete();
    await initialization.timeout(const Duration(seconds: 1));

    expect(initializationCompleted, isTrue);
    expect(await store.read(DatadogFlags.defaultClientName), isNotNull);
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

      await expectLater(
        client.initialize(_context).timeout(const Duration(seconds: 1)),
        _throwsInitializationTimeout(const Duration(milliseconds: 5)),
      );

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
      final repository = _repository(
        httpClient: httpClient,
        initializationTimeout: const Duration(seconds: 5),
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
      await expectLater(
        first.timeout(const Duration(seconds: 1)),
        _throwsInitializationTimeout(const Duration(seconds: 5)),
      );
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

  test('starts the timeout before synchronous request encoding', () async {
    var timerScheduled = false;
    final response = Completer<http.Response>();
    final httpClient = MockClient((_) => response.future);
    final repository = _repository(
      httpClient: httpClient,
      initializationTimeout: const Duration(milliseconds: 1),
      scheduleInitializationTimeout: (_, __) {
        timerScheduled = true;
        return _TestTimer();
      },
    );
    final context = FlagsEvaluationContext(
      targetingKey: 'user-123',
      attributes: {
        'observed': _CallbackIterable(
          () => expect(timerScheduled, isTrue),
        ),
      },
    );

    final initialization = repository.initialize(context);

    expect(timerScheduled, isTrue);
    response.complete(http.Response(jsonEncode(_assignmentsResponse()), 200));
    await initialization.timeout(const Duration(seconds: 1));
    expect(repository.flagAssignment('show-paywall'), isNotNull);
  });

  test('preserves store write order across SDK reconfiguration', () async {
    final store = _CrossLifecycleStore();
    final datadogFlags = DatadogFlags();
    addTearDown(() async {
      if (!store.allowFirstWrite.isCompleted) {
        store.allowFirstWrite.complete();
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
    final firstInitialization =
        datadogFlags.sharedClient().initialize(_context);
    await store.firstWriteStarted.future.timeout(const Duration(seconds: 1));
    await expectLater(
      firstInitialization.timeout(const Duration(seconds: 1)),
      _throwsInitializationTimeout(const Duration(milliseconds: 5)),
    );

    await datadogFlags.enable(
      configuration: _configuration(
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode(_assignmentsResponse(booleanValue: false)),
            200,
          );
        }),
        store: store,
        initializationTimeout: const Duration(milliseconds: 5),
      ),
    );
    final secondClient = datadogFlags.sharedClient();
    await expectLater(
      secondClient.initialize(_context).timeout(const Duration(seconds: 1)),
      _throwsInitializationTimeout(const Duration(milliseconds: 5)),
    );
    expect(
      secondClient
          .getBooleanDetails(key: 'show-paywall', defaultValue: true)
          .value,
      isFalse,
    );

    store.allowFirstWrite.complete();
    await store.firstWriteCompleted.future.timeout(const Duration(seconds: 1));
    await store.secondWriteCompleted.future.timeout(const Duration(seconds: 1));

    expect(
      store.data?.flags['show-paywall']?.variationValue,
      isFalse,
      reason: 'An older lifecycle must not overwrite newer stored assignments.',
    );
  });
}

const _context = FlagsEvaluationContext(targetingKey: 'user-123');

Matcher _throwsInitializationTimeout(Duration timeout) {
  return throwsA(
    isA<FlagsInitializationTimeoutException>()
        .having(
          (error) => error.clientName,
          'clientName',
          DatadogFlags.defaultClientName,
        )
        .having((error) => error.timeout, 'timeout', timeout),
  );
}

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

FlagsRepository _repository({
  required http.Client httpClient,
  Duration? initializationTimeout =
      DatadogFlagsConfiguration.defaultInitializationTimeout,
  DatadogFlagsStore? store,
  Timer Function(Duration, void Function()) scheduleInitializationTimeout =
      _scheduleTimer,
}) {
  final configuration = _configuration(
    httpClient: httpClient,
    initializationTimeout: initializationTimeout,
    store: store,
  );
  return FlagsRepository(
    clientName: DatadogFlags.defaultClientName,
    fetcher: FlagAssignmentsFetcher(
      datadogConfig: _datadogConfig,
      configuration: configuration,
      httpClient: httpClient,
    ),
    store: store,
    dateProvider: DateTime.now,
    initializationTimeout: initializationTimeout,
    scheduleInitializationTimeout: scheduleInitializationTimeout,
  );
}

Timer _scheduleTimer(Duration duration, void Function() action) {
  return Timer(duration, action);
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

void _blockFor(Duration duration) {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < duration) {}
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

class _DelayedReadStore implements DatadogFlagsStore {
  final InMemoryDatadogFlagsStore _delegate = InMemoryDatadogFlagsStore();
  final Completer<void> readStarted = Completer<void>();
  final Completer<void> allowRead = Completer<void>();

  @override
  Future<FlagsData?> read(String clientName) async {
    if (!readStarted.isCompleted) {
      readStarted.complete();
    }
    await allowRead.future;
    return _delegate.read(clientName);
  }

  @override
  Future<void> write(String clientName, FlagsData data) {
    return _delegate.write(clientName, data);
  }

  @override
  Future<void> delete(String clientName) {
    return _delegate.delete(clientName);
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

class _CrossLifecycleStore implements DatadogFlagsStore {
  final Completer<void> firstWriteStarted = Completer<void>();
  final Completer<void> allowFirstWrite = Completer<void>();
  final Completer<void> firstWriteCompleted = Completer<void>();
  final Completer<void> secondWriteCompleted = Completer<void>();

  FlagsData? data;
  var _writeCount = 0;

  @override
  Future<FlagsData?> read(String clientName) async => data;

  @override
  Future<void> write(String clientName, FlagsData value) async {
    _writeCount += 1;
    final writeNumber = _writeCount;
    if (writeNumber == 1) {
      firstWriteStarted.complete();
      await allowFirstWrite.future;
    }

    data = value;
    if (writeNumber == 1) {
      firstWriteCompleted.complete();
    } else if (writeNumber == 2) {
      secondWriteCompleted.complete();
    }
  }

  @override
  Future<void> delete(String clientName) async {
    data = null;
  }
}

class _BlockingReadStore implements DatadogFlagsStore {
  final FlagsData data;
  final Duration delay;

  _BlockingReadStore({required this.data, required this.delay});

  @override
  Future<FlagsData?> read(String clientName) {
    _blockFor(delay);
    return Future<FlagsData?>.value(data);
  }

  @override
  Future<void> write(String clientName, FlagsData data) async {}

  @override
  Future<void> delete(String clientName) async {}
}

class _TestTimer implements Timer {
  var _isActive = true;
  var cancelCount = 0;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => 0;

  @override
  void cancel() {
    cancelCount += 1;
    _isActive = false;
  }
}

class _CallbackIterable extends Iterable<Object?> {
  final void Function() onIterate;

  _CallbackIterable(this.onIterate);

  @override
  Iterator<Object?> get iterator {
    onIterate();
    return <Object?>[true].iterator;
  }
}
