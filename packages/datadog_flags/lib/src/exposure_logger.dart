// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import 'assignment.dart';
import 'evaluation_context.dart';
import 'flags_runtime.dart';
import 'json_value.dart';
import 'sdk_metadata.dart';

class ExposureLogger {
  static const Duration defaultUploadTimeout = Duration(seconds: 15);

  @visibleForTesting
  static Duration uploadTimeout = defaultUploadTimeout;

  final FlagsRuntime runtime;
  final Map<_ExposureCacheKey, _ExposureCacheValue> _loggedAssignments = {};
  final List<Map<String, Object?>> _pendingExposures = [];
  Future<bool>? _uploadInFlight;
  Future<void>? _shutdownInFlight;
  Timer? _flushTimer;
  bool _shutdownDrainActive = false;

  ExposureLogger(this.runtime);

  void logExposure({
    required String flagKey,
    required FlagAssignment assignment,
    required FlagsEvaluationContext evaluationContext,
  }) {
    final configuration = runtime.configuration;
    if (!configuration.trackExposures || !assignment.doLog) {
      return;
    }

    final cacheKey = _ExposureCacheKey(
      targetingKey: evaluationContext.targetingKey,
      flagKey: flagKey,
    );
    final cacheValue = _ExposureCacheValue(
      allocationKey: assignment.allocationKey,
      variationKey: assignment.variationKey,
    );
    if (_loggedAssignments[cacheKey] == cacheValue) {
      return;
    }
    _loggedAssignments[cacheKey] = cacheValue;

    _pendingExposures.add(
      _buildExposureEvent(
        flagKey: flagKey,
        assignment: assignment,
        evaluationContext: evaluationContext,
      ),
    );
    _scheduleFlush();
  }

  Future<void> shutdown() {
    _flushTimer?.cancel();
    _flushTimer = null;

    final shutdownInFlight = _shutdownInFlight;
    if (shutdownInFlight != null) {
      return shutdownInFlight;
    }

    late final Future<void> shutdownOperation;
    shutdownOperation = _shutdownDrain().whenComplete(() {
      if (identical(_shutdownInFlight, shutdownOperation)) {
        _shutdownInFlight = null;
      }
    });
    _shutdownInFlight = shutdownOperation;
    return shutdownOperation;
  }

  Future<void> _shutdownDrain() async {
    _shutdownDrainActive = true;
    try {
      final activeUpload = _uploadInFlight;
      if (activeUpload != null) {
        final succeeded = await activeUpload;
        if (!succeeded) {
          return;
        }
      }

      await _uploadPendingExposures(rescheduleOnFailure: false);
    } finally {
      _shutdownDrainActive = false;
    }
  }

  Future<void> _flushPendingExposures({
    required bool rescheduleOnFailure,
  }) async {
    if (_uploadInFlight != null) {
      _scheduleRetryFlush();
      return;
    }

    await _uploadPendingExposures(
      rescheduleOnFailure: rescheduleOnFailure,
    );
  }

  Future<bool> _uploadPendingExposures({
    required bool rescheduleOnFailure,
  }) {
    final activeUpload = _uploadInFlight;
    if (activeUpload != null) {
      return activeUpload;
    }

    if (_pendingExposures.isEmpty) {
      return Future.value(true);
    }

    final exposures = List<Map<String, Object?>>.from(_pendingExposures);
    _pendingExposures.clear();

    late final Future<bool> uploadOperation;
    uploadOperation = _sendExposures(
      exposures,
      rescheduleOnFailure: rescheduleOnFailure,
    ).whenComplete(() {
      if (identical(_uploadInFlight, uploadOperation)) {
        _uploadInFlight = null;
      }
    });
    _uploadInFlight = uploadOperation;
    return uploadOperation;
  }

  Future<bool> _sendExposures(
    List<Map<String, Object?>> exposures, {
    required bool rescheduleOnFailure,
  }) async {
    try {
      final response = await runtime.httpClient
          .post(
            _exposureEndpoint(),
            headers: {
              'Content-Type': 'text/plain;charset=UTF-8',
              'DD-API-KEY': runtime.datadogConfig.clientToken,
              'DD-EVP-ORIGIN': datadogFlagsSource,
              'DD-EVP-ORIGIN-VERSION': datadogFlagsSdkVersion,
              'DD-REQUEST-ID': const Uuid().v4(),
            },
            body: exposures.map(jsonEncode).join('\n'),
          )
          .timeout(uploadTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (shouldRetryFlagsUpload(response.statusCode)) {
          _restore(exposures, reschedule: rescheduleOnFailure);
          return false;
        }
        return true;
      }
      return true;
    } catch (_) {
      _restore(exposures, reschedule: rescheduleOnFailure);
      return false;
    }
  }

  Map<String, Object?> _buildExposureEvent({
    required String flagKey,
    required FlagAssignment assignment,
    required FlagsEvaluationContext evaluationContext,
  }) {
    final subject = _removeNullValues({
      'id': evaluationContext.targetingKey,
      'attributes': sanitizeJsonValue(evaluationContext.attributes),
    });
    return {
      'timestamp': runtime.configuration.dateProvider().millisecondsSinceEpoch,
      'allocation': {'key': assignment.allocationKey},
      'flag': {'key': flagKey},
      'variant': {'key': assignment.variationKey},
      'subject': subject,
    };
  }

  void _restore(
    List<Map<String, Object?>> exposures, {
    required bool reschedule,
  }) {
    _pendingExposures.insertAll(0, exposures);
    if (reschedule && !_shutdownDrainActive) {
      _scheduleRetryFlush();
    }
  }

  void _scheduleFlush() {
    _scheduleFlushAfter(
      _uploadInFlight == null ? _exposureFlushDelay : _exposureFlushRetryDelay,
    );
  }

  void _scheduleRetryFlush() {
    _scheduleFlushAfter(_exposureFlushRetryDelay);
  }

  void _scheduleFlushAfter(Duration delay) {
    if (_shutdownDrainActive || _flushTimer != null) {
      return;
    }

    _flushTimer = Timer(delay, () {
      _flushTimer = null;
      unawaited(_flushPendingExposures(rescheduleOnFailure: true));
    });
  }

  Uri _exposureEndpoint() {
    final datadogConfig = runtime.datadogConfig;
    final endpoint = runtime.configuration.customExposureEndpoint ??
        datadogConfig.intakeEndpoint().replace(path: '/api/v2/exposures');
    return endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        'ddsource': datadogFlagsSource,
      },
    );
  }
}

@immutable
final class _ExposureCacheKey {
  final String? targetingKey;
  final String flagKey;

  const _ExposureCacheKey({
    required this.targetingKey,
    required this.flagKey,
  });

  @override
  bool operator ==(Object other) {
    return other is _ExposureCacheKey &&
        other.targetingKey == targetingKey &&
        other.flagKey == flagKey;
  }

  @override
  int get hashCode {
    return Object.hash(targetingKey, flagKey);
  }
}

@immutable
final class _ExposureCacheValue {
  final String allocationKey;
  final String variationKey;

  const _ExposureCacheValue({
    required this.allocationKey,
    required this.variationKey,
  });

  @override
  bool operator ==(Object other) {
    return other is _ExposureCacheValue &&
        other.allocationKey == allocationKey &&
        other.variationKey == variationKey;
  }

  @override
  int get hashCode {
    return Object.hash(allocationKey, variationKey);
  }
}

const _exposureFlushDelay = Duration(seconds: 10);
const _exposureFlushRetryDelay = Duration(milliseconds: 500);

Map<String, Object?> _removeNullValues(Map<String, Object?> input) {
  return Map.fromEntries(input.entries.where((entry) => entry.value != null));
}
