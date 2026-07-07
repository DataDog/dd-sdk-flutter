// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

/// Native Dart client for Datadog Feature Flags and Experimentation.
///
/// Use [DatadogFlags] to configure the SDK, create named
/// [DatadogFlagsClient] instances, and evaluate precomputed flag assignments
/// for a [FlagsEvaluationContext].
library;

export 'src/datadog_flags_config.dart'
    show DatadogFlagsConfig, DatadogFlagsSite;
export 'src/datadog_flags.dart' show DatadogFlags;
export 'src/flags_client.dart' show DatadogFlagsClient, FlagDetails;
export 'src/flags_configuration.dart' show DatadogFlagsConfiguration;
export 'src/flags_error.dart' show FlagEvaluationError;
export 'src/flags_store.dart' show DatadogFlagsStore, FlagsData;
export 'src/evaluation_context.dart' show FlagsEvaluationContext;
