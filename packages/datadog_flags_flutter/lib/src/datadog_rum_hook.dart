// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

/// Adds successful OpenFeature evaluations to the active Datadog RUM view.
///
/// Register once on the OpenFeature client used by the application.
final class DatadogRumHook extends HookAdapter {
  final DatadogSdk _sdk;

  /// Uses [sdk], or the default Datadog Flutter SDK instance.
  DatadogRumHook({DatadogSdk? sdk}) : _sdk = sdk ?? DatadogSdk.instance;

  @override
  void after(
    HookContext context,
    FlagEvaluationDetails<Object> details,
    HookHints hints,
  ) {
    if (details.errorCode == null) {
      _sdk.rum?.addFeatureFlagEvaluation(
        context.flagKey,
        details.variant ?? details.value,
      );
    }
  }
}
