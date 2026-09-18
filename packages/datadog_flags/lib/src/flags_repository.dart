// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'package:meta/meta.dart';

import 'assignment.dart';
import 'evaluation_context.dart';
import 'flag_assignments_fetcher.dart';
import 'flags_error.dart';
import 'flags_store.dart';
import 'json_value.dart';

class FlagsRepository {
  static const defaultStoreReadTimeout = Duration(milliseconds: 100);

  // Keep late writes ordered when SDK reconfiguration replaces a repository.
  // Expando keeps the queue scoped to the store identity without retaining it.
  static final Expando<Map<String, _CacheOperationQueue>>
      _cacheOperationQueues =
      Expando<Map<String, _CacheOperationQueue>>('flags cache operations');

  @visibleForTesting
  final Duration storeReadTimeout;

  final String clientName;
  final FlagAssignmentsFetcher fetcher;
  final DatadogFlagsStore? store;
  final DateTime Function() dateProvider;
  final Duration? initializationTimeout;
  final _CacheOperationQueue _cacheOperations;

  @visibleForTesting
  final Timer Function(Duration, void Function()) scheduleInitializationTimeout;

  FlagsData? _state;
  _CancelToken? _currentToken;
  bool _didStartInitialization = false;

  FlagsRepository({
    required this.clientName,
    required this.fetcher,
    this.store,
    required this.dateProvider,
    this.initializationTimeout,
    this.storeReadTimeout = defaultStoreReadTimeout,
    this.scheduleInitializationTimeout = _scheduleInitializationTimeout,
  }) : _cacheOperations = _cacheOperationQueue(store, clientName);

  FlagsEvaluationContext? get context => _state?.context;

  FlagAssignment? flagAssignment(String key) => _state?.flags[key];

  Future<void> initialize(FlagsEvaluationContext context) {
    _currentToken?.cancel();
    final token = _CancelToken();
    _currentToken = token;

    final timeout = _takeInitializationTimeout();
    if (timeout == null) {
      return _initialize(context, token);
    }

    final timeoutCompletion = Completer<void>();
    final timer = scheduleInitializationTimeout(
      timeout,
      () => timeoutCompletion.completeError(
        FlagsInitializationTimeoutException(
          clientName: clientName,
          timeout: timeout,
        ),
        StackTrace.current,
      ),
    );
    final operation = _initialize(context, token);
    return Future.any<void>([
      operation,
      timeoutCompletion.future,
    ]).whenComplete(timer.cancel);
  }

  Future<void> _initialize(
    FlagsEvaluationContext context,
    _CancelToken token,
  ) async {
    final cached = store == null ? null : await _readCached();
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
      final data = FlagsData(
        flags: assignments.flags,
        context: context,
        date: dateProvider(),
      );
      _state = data;
      await _writeCached(data);
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

  static _CacheOperationQueue _cacheOperationQueue(
    DatadogFlagsStore? store,
    String clientName,
  ) {
    if (store == null) {
      return _CacheOperationQueue();
    }

    final queues =
        _cacheOperationQueues[store] ??= <String, _CacheOperationQueue>{};
    return queues.putIfAbsent(clientName, _CacheOperationQueue.new);
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
    await _cacheOperations.enqueue(() async {
      try {
        await store?.write(clientName, data);
      } catch (_) {
        return;
      }
    });
  }

  Future<void> _deleteCached() async {
    await _cacheOperations.enqueue(() async {
      try {
        await store?.delete(clientName);
      } catch (_) {
        return;
      }
    });
  }
}

class _CacheOperationQueue {
  Future<void> _operation = Future<void>.value();

  Future<void> enqueue(Future<void> Function() operation) {
    final next = _operation.then((_) => operation());
    _operation = next.catchError((_) {});
    return next;
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
