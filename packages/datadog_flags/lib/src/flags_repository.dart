// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'package:meta/meta.dart';

import 'assignment.dart';
import 'evaluation_context.dart';
import 'flag_assignments_fetcher.dart';
import 'flags_client.dart';
import 'flags_error.dart';
import 'flags_store.dart';

class FlagsRepository {
  static const defaultStoreReadTimeout = Duration(milliseconds: 100);

  // Keep late writes ordered when SDK reconfiguration replaces a repository.
  // Expando keeps the queue scoped to the store identity without retaining it.
  static final Expando<Map<String, _CacheOperationQueue>>
  _cacheOperationQueues = Expando<Map<String, _CacheOperationQueue>>(
    'flags cache operations',
  );

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

  _InstalledFlagsState? _state;
  bool _assignmentsWithheld = false;
  bool _requiresFreshAssignments = false;
  DatadogFlagsClientStatus _status = DatadogFlagsClientStatus.notReady;
  final StreamController<DatadogFlagsClientStatus> _statusChanges =
      StreamController<DatadogFlagsClientStatus>.broadcast(sync: true);
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

  FlagsEvaluationContext? get context =>
      _assignmentsWithheld ? null : _state?.data.context;

  DatadogFlagsClientStatus get status => _status;

  Object? lastLoadError;

  Stream<DatadogFlagsClientStatus> get statusChanges => _statusChanges.stream;

  FlagAssignment? flagAssignment(String key) {
    final data = _assignmentsWithheld ? null : _state?.data;
    if (data == null) return null;
    final encoding = data.obfuscation;
    final lookupKey = encoding == null ? key : encoding.encodeKey(key);
    return lookupKey == null ? null : data.flags[lookupKey];
  }

  bool get isRestoredFromStore => _state?.restoredFromStore ?? false;

  Future<void> initialize(FlagsEvaluationContext context) {
    _currentToken?.cancel();
    final installed = _state?.data.context;
    if (installed != null && !_eligible(installed, context)) {
      _assignmentsWithheld = true;
      _setStatus(DatadogFlagsClientStatus.notReady);
    }
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
        cached != null &&
            !_requiresFreshAssignments &&
            targetingContextsMatch(cached.context, context)
        ? cached
        : null;
    if (matchingCached != null && !_hasCurrentStateForContext(context)) {
      _assignmentsWithheld = false;
      _requiresFreshAssignments = false;
      _state = _InstalledFlagsState(
        data: FlagsData(
          flags: matchingCached.flags,
          context: matchingCached.context.targetingContext,
          date: matchingCached.date,
          obfuscation: matchingCached.obfuscation,
        ),
        restoredFromStore: true,
      );
      _setStatus(DatadogFlagsClientStatus.stale);
    }

    try {
      final assignments = await fetcher.fetch(context);
      if (token.isCanceled) {
        return;
      }
      final data = FlagsData(
        flags: assignments.flags,
        context: context.targetingContext,
        date: dateProvider(),
        obfuscation: assignments.obfuscation,
      );
      lastLoadError = null;
      _assignmentsWithheld = false;
      _requiresFreshAssignments = false;
      _state = _InstalledFlagsState(data: data, restoredFromStore: false);
      _setStatus(DatadogFlagsClientStatus.ready);
      await _writeCached(data);
    } on Object catch (error) {
      if (!token.isCanceled) lastLoadError = error;
      if (token.isCanceled) return;
      if (context.strictContextSwitching) {
        _assignmentsWithheld = true;
        _requiresFreshAssignments = true;
      }
      if (_assignmentsWithheld ||
          (matchingCached == null && !_hasCurrentStateForContext(context))) {
        _assignmentsWithheld = true;
        _setStatus(DatadogFlagsClientStatus.error);
      } else if (!token.isCanceled) {
        _setStatus(DatadogFlagsClientStatus.stale);
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

    final queues = _cacheOperationQueues[store] ??=
        <String, _CacheOperationQueue>{};
    return queues.putIfAbsent(clientName, _CacheOperationQueue.new);
  }

  bool _hasCurrentStateForContext(FlagsEvaluationContext context) {
    final current = _state;
    return !_assignmentsWithheld &&
        current != null &&
        _eligible(current.data.context, context);
  }

  bool _eligible(
    FlagsEvaluationContext installed,
    FlagsEvaluationContext requested,
  ) =>
      (installed.targetingKey ?? '') == (requested.targetingKey ?? '') &&
      (!requested.strictContextSwitching ||
          targetingContextsMatch(installed, requested));

  Future<void> clearMemory() async {
    _currentToken?.cancel();
    _currentToken = null;
    _state = null;
    _assignmentsWithheld = false;
    _requiresFreshAssignments = false;
    _setStatus(DatadogFlagsClientStatus.notReady);
  }

  Future<void> dispose() async {
    await clearMemory();
    if (!_statusChanges.isClosed) {
      // Paused application listeners must not delay SDK cleanup.
      unawaited(_statusChanges.close());
    }
  }

  Future<void> reset() async {
    await clearMemory();
    await _deleteCached();
  }

  void _setStatus(DatadogFlagsClientStatus status) {
    if (_status == status) {
      return;
    }
    _status = status;
    if (!_statusChanges.isClosed) {
      _statusChanges.add(status);
    }
  }

  Future<FlagsData?> _readCached() async {
    final store = this.store;
    if (store == null) {
      return null;
    }

    try {
      final data = await store
          .read(clientName)
          .timeout(storeReadTimeout, onTimeout: () => null);
      // Custom stores can return constructed snapshots without JSON decoding.
      // Validate and copy the complete snapshot before making it available.
      return data == null ? null : FlagsData.fromJson(data.toJson());
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

@immutable
class _InstalledFlagsState {
  final FlagsData data;
  final bool restoredFromStore;

  const _InstalledFlagsState({
    required this.data,
    required this.restoredFromStore,
  });
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
