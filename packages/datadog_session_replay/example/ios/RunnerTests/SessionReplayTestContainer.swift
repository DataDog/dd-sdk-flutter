// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Testing

/// Parent suite that serializes all tests sharing `FlutterSessionReplay` global static state.
///
/// Both `DatadogSessionReplayPluginTests` and `FlutterSessionReplayBridgeTests` mutate the same
/// static properties on `FlutterSessionReplay`. Without a shared serialization boundary their
/// `init()`/`deinit` calls to `shutdown()` can race with a sibling suite's test body, producing
/// flaky failures. Nesting both suites here under `.serialized` prevents any two tests from those
/// suites running concurrently.
@Suite(.serialized)
enum SessionReplayTestContainer {}
