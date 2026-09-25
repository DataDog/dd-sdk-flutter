// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

/// Native Dart client for Datadog Feature Flags and Experimentation.
///
/// Register [DatadogOpenFeatureProvider] with OpenFeatureAPI and evaluate flags
/// through OpenFeatureClient. The legacy Datadog evaluation API is deprecated.
library;

export 'src/datadog_flags_config.dart'
    show DatadogFlagsConfig, DatadogFlagsSite;
export 'src/datadog_flags.dart' show DatadogFlags;
export 'src/datadog_openfeature_provider.dart' show DatadogOpenFeatureProvider;
export 'src/flags_client.dart'
    show
        DatadogFlagsClient,
        DatadogFlagsClientLifecycle,
        DatadogFlagsClientStatus,
        FlagDetails;
export 'src/flags_configuration.dart' show DatadogFlagsConfiguration;
export 'src/flags_error.dart'
    show FlagEvaluationError, FlagsInitializationTimeoutException;
export 'src/flags_store.dart' show DatadogFlagsStore, FlagsData;
export 'src/evaluation_context.dart' show FlagsEvaluationContext;
