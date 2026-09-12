// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'package:meta/meta.dart';

import 'assignment.dart';
import 'evaluation_context.dart';
import 'flag_assignments_fetcher.dart';
import 'flags_store.dart';
import 'json_value.dart';

class FlagsRepository {
  static const defaultStoreReadTimeout = Duration(milliseconds: 100);

  @visibleForTesting
  final Duration storeReadTimeout;

  final String clientName;
  final FlagAssignmentsFetcher fetcher;
  final DatadogFlagsStore? store;
  final DateTime Function() dateProvider;
  final Duration? initializationTimeout;

  @visibleForTesting
  final Timer Function(Duration, void Function()) scheduleInitializationTimeout;

  FlagsData? _state;
  _CancelToken? _currentToken;
  Future<void> _cacheOperation = Future<void>.value();
  bool _didStartInitialization = false;

  FlagsRepository({
    required this.clientName,
    required this.fetcher,
    this.store,
    required this.dateProvider,
    this.initializationTimeout,
    this.storeReadTimeout = defaultStoreReadTimeout,
    this.scheduleInitializationTimeout = _scheduleInitializationTimeout,
  });

  FlagsEvaluationContext? get context => _state?.context;

  FlagAssignment? flagAssignment(String key) => _state?.flags[key];

  Future<void> initialize(FlagsEvaluationContext context) {
    _currentToken?.cancel();
    final token = _CancelToken();
    _currentToken = token;

    final timeout = _takeInitializationTimeout();
    final deadline = timeout == null
        ? null
        : _InitializationDeadline(timeout, scheduleInitializationTimeout);
    final operation = _initialize(context, token, deadline);
    if (deadline == null) {
      return operation;
    }
    deadline.observe(operation);
    return deadline.future;
  }

  Future<void> _initialize(
    FlagsEvaluationContext context,
    _CancelToken token,
    _InitializationDeadline? deadline,
  ) async {
    final cached = store == null ? null : await _readCached();
    if (token.isCanceled) {
      return;
    }
    final cacheDeadlineYield = _yieldAfterExpiredDeadline(deadline);
    if (cacheDeadlineYield != null) {
      await cacheDeadlineYield;
    }
    if (token.isCanceled) {
      return;
    }

    final matchingCached =
        cached != null && _contextsMatch(cached.context, context)
            ? cached
            : null;
    if (matchingCached != null && !_hasCurrentStateForContext(context)) {
      _state = matchingCached;
    }

    try {
      final assignments = await fetcher.fetch(context);
      if (token.isCanceled) {
        return;
      }
      final fetchDeadlineYield = _yieldAfterExpiredDeadline(deadline);
      if (fetchDeadlineYield != null) {
        await fetchDeadlineYield;
      }
      if (token.isCanceled) {
        return;
      }
      final data = FlagsData(
        flags: assignments.flags,
        context: context,
        date: dateProvider(),
      );
      await _writeCached(data);
      if (token.isCanceled) {
        return;
      }
      final publicationDeadlineYield = _yieldAfterExpiredDeadline(deadline);
      if (publicationDeadlineYield != null) {
        await publicationDeadlineYield;
      }
      if (token.isCanceled) {
        return;
      }
      _state = data;
    } catch (_) {
      if (!token.isCanceled && matchingCached == null) {
        _state = null;
      }
    }
  }

  Duration? _takeInitializationTimeout() {
    if (_didStartInitialization) {
      return null;
    }
    _didStartInitialization = true;
    final timeout = initializationTimeout;
    return timeout != null && timeout > Duration.zero ? timeout : null;
  }

  static Timer _scheduleInitializationTimeout(
    Duration timeout,
    void Function() action,
  ) {
    return Timer(timeout, action);
  }

  static Future<void>? _yieldAfterExpiredDeadline(
    _InitializationDeadline? deadline,
  ) {
    if (deadline?.expireIfNeeded() ?? false) {
      return Future<void>.delayed(Duration.zero);
    }
    return null;
  }

  bool _hasCurrentStateForContext(FlagsEvaluationContext context) {
    final current = _state;
    return current != null && _contextsMatch(current.context, context);
  }

  Future<void> clearMemory() async {
    _currentToken?.cancel();
    _currentToken = null;
    _state = null;
  }

  Future<void> reset() async {
    await clearMemory();
    await _deleteCached();
  }

  Future<FlagsData?> _readCached() async {
    final store = this.store;
    if (store == null) {
      return null;
    }

    try {
      return await store.read(clientName).timeout(
            storeReadTimeout,
            onTimeout: () => null,
          );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCached(FlagsData data) async {
    await _enqueueCacheOperation(() async {
      try {
        await store?.write(clientName, data);
      } catch (_) {
        return;
      }
    });
  }

  Future<void> _deleteCached() async {
    await _enqueueCacheOperation(() async {
      try {
        await store?.delete(clientName);
      } catch (_) {
        return;
      }
    });
  }

  Future<void> _enqueueCacheOperation(Future<void> Function() operation) {
    final next = _cacheOperation.then((_) => operation());
    _cacheOperation = next.catchError((_) {});
    return next;
  }
}

class _InitializationDeadline {
  // Dart timers cannot run while synchronous encoding or decoding blocks the
  // isolate. The stopwatch checks enforce the wall-clock deadline before the
  // operation can publish assignments or win the completion race.
  final Duration timeout;
  final Completer<void> _completion = Completer<void>();
  final Stopwatch _stopwatch = Stopwatch()..start();
  Timer? _timer;
  var _expired = false;

  _InitializationDeadline(
    this.timeout,
    Timer Function(Duration, void Function()) schedule,
  ) {
    _timer = schedule(timeout, _expire);
    if (_expired) {
      _timer?.cancel();
    }
  }

  Future<void> get future => _completion.future;

  bool expireIfNeeded() {
    if (!_expired && _stopwatch.elapsed >= timeout) {
      _expire();
    }
    return _expired;
  }

  void observe(Future<void> operation) {
    expireIfNeeded();
    operation.then<void>(
      (_) => _completeOperation(),
      onError: _completeOperationWithError,
    );
  }

  void _expire() {
    if (_completion.isCompleted) {
      return;
    }
    _expired = true;
    _stopwatch.stop();
    _timer?.cancel();
    _completion.complete();
  }

  void _completeOperation() {
    if (expireIfNeeded()) {
      return;
    }
    _stopwatch.stop();
    _timer?.cancel();
    _completion.complete();
  }

  void _completeOperationWithError(Object error, StackTrace stackTrace) {
    if (expireIfNeeded()) {
      return;
    }
    _stopwatch.stop();
    _timer?.cancel();
    _completion.completeError(error, stackTrace);
  }
}

class _CancelToken {
  var _canceled = false;

  bool get isCanceled => _canceled;

  void cancel() {
    _canceled = true;
  }
}

bool _contextsMatch(FlagsEvaluationContext left, FlagsEvaluationContext right) {
  if (left.targetingKey != right.targetingKey) {
    return false;
  }

  try {
    return _jsonValuesMatch(
      sanitizeJsonValue(left.attributes),
      sanitizeJsonValue(right.attributes),
    );
  } catch (_) {
    return false;
  }
}

bool _jsonValuesMatch(Object? left, Object? right) {
  if (left is Map<Object?, Object?> && right is Map<Object?, Object?>) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_jsonValuesMatch(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (left is Iterable<Object?> && right is Iterable<Object?>) {
    final leftIterator = left.iterator;
    final rightIterator = right.iterator;
    while (true) {
      final hasLeft = leftIterator.moveNext();
      final hasRight = rightIterator.moveNext();
      if (hasLeft != hasRight) {
        return false;
      }
      if (!hasLeft) {
        return true;
      }
      if (!_jsonValuesMatch(leftIterator.current, rightIterator.current)) {
        return false;
      }
    }
  }
  return left == right;
}
