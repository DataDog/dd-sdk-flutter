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

enum _ExposureVerdict {
  none(isExposure: false, isCacheHit: false),
  newExposure(isExposure: true, isCacheHit: false),
  cacheHit(isExposure: true, isCacheHit: true);

  final bool isExposure;
  final bool isCacheHit;

  const _ExposureVerdict({required this.isExposure, required this.isCacheHit});
}

// OpenFeature passes the same details instance to every finally hook of one
// evaluation. The provider hook marks that instance before any other finally
// hook runs, so the mark shows that the evaluation ran the provider hooks.
final Expando<_ExposureVerdict> _exposureVerdicts = Expando(
  'datadog exposure verdicts',
);

/// Marks [details] as an evaluation that ran the Datadog provider hooks.
void markDatadogEvaluation(FlagEvaluationDetails<Object> details) {
  _exposureVerdicts[details] = _ExposureVerdict.none;
}

void recordExposureDecision(
  FlagEvaluationDetails<Object> details, {
  required bool isCacheHit,
}) {
  _exposureVerdicts[details] = isCacheHit
      ? _ExposureVerdict.cacheHit
      : _ExposureVerdict.newExposure;
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
/// OpenFeature runs before this one. Exposures need the
/// `DatadogOpenFeatureProvider` as the OpenFeature provider, or a provider that
/// wraps it and returns its `hooks` and its `metadata`. The provider records
/// exposures in its `hooks`, and this hook recognizes its evaluations by its
/// `metadata`. Evaluations from a provider with other metadata are skipped.
/// Evaluations through a wrapper that returns only the `metadata` reach the
/// callback with [ExposureEvaluation.isExposure] false, and the hook logs a
/// warning.
final class ExposureHook extends HookAdapter {
  static const _maxWarnedProviders = 8;

  final ExposureCallback _callback;
  final FlagsLogger _logger;
  bool _callbackFailed = false;
  bool _warnedMissingHooks = false;
  final Set<String> _warnedProviders = {};

  /// Creates a hook that passes each completed evaluation to [callback].
  ExposureHook(ExposureCallback callback)
    : this._(callback, const FlagsLogger());

  ExposureHook._(this._callback, this._logger);

  @override
  void finallyAfter(
    HookContext context,
    FlagEvaluationDetails<Object> details,
    HookHints hints,
  ) {
    try {
      final name = context.providerMetadata.name;
      if (name != datadogProviderName) {
        if (_warnedProviders.length < _maxWarnedProviders &&
            _warnedProviders.add(name)) {
          _logger.warning(
            'ExposureHook skips evaluations from provider "$name".',
          );
        }
        return;
      }
      final marked = _exposureVerdicts[details];
      final verdict = marked ?? _ExposureVerdict.none;
      if (marked == null && !_warnedMissingHooks) {
        _warnedMissingHooks = true;
        _logger.warning(
          'ExposureHook received an evaluation that skipped the '
          'DatadogOpenFeatureProvider hooks, so no exposure was recorded.',
        );
      }
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
          isExposure: verdict.isExposure,
          isCacheHit: verdict.isCacheHit,
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

/// Creates an [ExposureHook] that writes its diagnostics to [logger].
@visibleForTesting
ExposureHook exposureHookWithLogger(
  ExposureCallback callback,
  FlagsLogger logger,
) => ExposureHook._(callback, logger);
