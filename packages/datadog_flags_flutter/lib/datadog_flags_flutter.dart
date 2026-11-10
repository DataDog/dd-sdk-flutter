// Legacy API compatibility until the next major release.
// ignore_for_file: deprecated_member_use

// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

export 'package:datadog_flags/datadog_flags.dart'
    show
        DatadogOpenFeatureProvider,
        DatadogFlagsConfig,
        DatadogFlagsClient,
        DatadogFlagsConfiguration,
        DatadogFlagsSite,
        DatadogFlagsStore,
        FlagDetails,
        FlagEvaluationError,
        FlagsInitializationTimeoutException,
        FlagsData,
        FlagsEvaluationContext;

export 'src/datadog_flags_plugin.dart';

export 'src/datadog_rum_hook.dart';
