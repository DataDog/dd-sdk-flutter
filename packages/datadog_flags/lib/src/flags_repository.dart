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

  FlagsData? _state;
  _CancelToken? _currentToken;
  Future<void> _cacheOperation = Future<void>.value();

  FlagsRepository({
    required this.clientName,
    required this.fetcher,
    this.store,
    required this.dateProvider,
    this.storeReadTimeout = defaultStoreReadTimeout,
  });

  FlagsEvaluationContext? get context => _state?.context;

  FlagAssignment? flagAssignment(String key) => _state?.flags[key];

  Future<void> initialize(FlagsEvaluationContext context) async {
    _currentToken?.cancel();
    final token = _CancelToken();
    _currentToken = token;

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
