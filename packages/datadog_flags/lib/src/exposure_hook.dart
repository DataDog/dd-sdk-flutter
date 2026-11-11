// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:meta/meta.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

import 'flags_client.dart';
import 'flags_log.dart';
import 'split_features.dart';

const doLogMetadata = '__dd_do_log';
const splitSerialIdMetadata = '__dd_split_serial_id';
const datadogProviderName = 'Datadog';

// OpenFeature passes the same details instance to every finally hook of one
// evaluation, so the provider's verdict is attached to that instance.
final Expando<bool> _exposureCacheHits = Expando('datadog exposure verdicts');

void recordExposureDecision(
  FlagEvaluationDetails<Object> details, {
  required bool isCacheHit,
}) {
  _exposureCacheHits[details] = isCacheHit;
}

/// Receives each completed evaluation of [ExposureHook].
typedef ExposureCallback = void Function(ExposureEvaluation evaluation);

/// A completed flag evaluation, with the Datadog exposure verdict.
@immutable
final class ExposureEvaluation {
  /// Flag key that was evaluated.
  final String flagKey;

  /// Variant of the assignment, or `null` when the evaluation failed.
  final String? variant;

  /// Allocation key of the assignment, or `null` when the evaluation failed.
  final String? allocationKey;

  /// Targeting key of the evaluation context.
  final String? targetingKey;

  /// Evaluation context used for this evaluation.
  final EvaluationContext evaluationContext;

  /// Features of the selected split that are published to hooks, such as
  /// `holdout.key`. Values are [String], [double], or [bool].
  final Map<String, Object> features;

  final bool _isExposure;
  final bool _isCacheHit;

  const ExposureEvaluation._({
    required this.flagKey,
    required this.variant,
    required this.allocationKey,
    required this.targetingKey,
    required this.evaluationContext,
    required this.features,
    required bool isExposure,
    required bool isCacheHit,
  }) : _isExposure = isExposure,
       _isCacheHit = isCacheHit;

  /// Whether this is a successful evaluation of an allocation that logs
  /// exposures, repeats included.
  bool get isExposure => _isExposure;

  /// Whether the subject was already exposed to this assignment.
  bool get isCacheHit => _isCacheHit;

  /// Whether this is a new exposure: the evaluations that the SDK sends to
  /// Datadog when exposure tracking is on.
  bool get shouldSend => _isExposure && !_isCacheHit;
}

/// An OpenFeature hook that passes each completed evaluation of a
/// `DatadogOpenFeatureProvider` to a callback.
///
/// Use it to record exposures in your own data store. The callback receives
/// the same deduplication verdict that the SDK uses for Datadog, also when
/// `trackExposures` is off. It runs synchronously on the evaluating isolate
/// for every evaluation, so it must be fast and must not do I/O. Exceptions
/// from the callback are caught and logged; they never change the evaluation.
///
/// The provider decides the exposure in its own `finallyAfter` hook, which
/// OpenFeature runs before this one. Evaluations from other providers,
/// including providers that wrap the Datadog provider, are skipped.
final class ExposureHook extends HookAdapter {
  final ExposureCallback _callback;
  final FlagsLogger _logger;
  bool _callbackFailed = false;
  bool _warnedOtherProvider = false;

  /// Creates a hook that passes each completed evaluation to [callback].
  ExposureHook(ExposureCallback callback)
    : this.withLogger(callback, const FlagsLogger());

  @visibleForTesting
  ExposureHook.withLogger(this._callback, this._logger);

  @override
  void finallyAfter(
    HookContext context,
    FlagEvaluationDetails<Object> details,
    HookHints hints,
  ) {
    try {
      if (context.providerMetadata.name != datadogProviderName) {
        if (!_warnedOtherProvider) {
          _warnedOtherProvider = true;
          _logger.warning(
            'ExposureHook skips evaluations from provider '
            '"${context.providerMetadata.name}".',
          );
        }
        return;
      }
      final isCacheHit = _exposureCacheHits[details];
      final metadata = details.flagMetadata;
      final allocationKey = metadata[datadogAllocationKeyMetadata];
      _callback(
        ExposureEvaluation._(
          flagKey: context.flagKey,
          variant: details.variant,
          allocationKey: allocationKey is String ? allocationKey : null,
          targetingKey: context.evaluationContext.targetingKey,
          evaluationContext: context.evaluationContext,
          features: splitFeaturesFromMetadata(
            metadata,
            SplitFeatureDestination.hook,
          ),
          isExposure: isCacheHit != null,
          isCacheHit: isCacheHit ?? false,
        ),
      );
    } catch (error) {
      _logCallbackError(error);
    }
  }

  void _logCallbackError(Object error) {
    try {
      const message = 'ExposureHook callback failed.';
      if (_callbackFailed) {
        _logger.debug(message, error: error);
      } else {
        _callbackFailed = true;
        _logger.warning(message, error: error);
      }
    } catch (_) {}
  }
}
