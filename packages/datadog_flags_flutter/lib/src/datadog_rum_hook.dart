// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

/// Adds successful OpenFeature evaluations to the active Datadog RUM view.
///
/// Register with [OpenFeatureAPI.addHooks] and register again after shutdown.
/// Client hooks apply only to that client object; [OpenFeatureAPI.getClient]
/// returns a new client on each call.
final class DatadogRumHook extends HookAdapter {
  final DatadogSdk _sdk;

  /// Uses [sdk], or the default Datadog Flutter SDK instance.
  DatadogRumHook({DatadogSdk? sdk}) : _sdk = sdk ?? DatadogSdk.instance;

  @override
  void finallyAfter(
    HookContext context,
    FlagEvaluationDetails<Object> details,
    HookHints hints,
  ) {
    if (details.errorCode != null || details.reason == 'ERROR') return;
    if (details.variant case final variant?) {
      _sdk.rum?.addFeatureFlagEvaluation(details.flagKey, variant);
    }
  }
}
