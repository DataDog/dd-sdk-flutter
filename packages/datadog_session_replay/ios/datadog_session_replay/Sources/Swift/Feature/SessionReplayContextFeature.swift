// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import Foundation
import DatadogInternal

/// Stands in for the native Session Replay feature under its name when Flutter Session Replay runs
/// standalone, as the Android plugin does, so that Flutter owns the replay state it publishes
/// (`has_replay`, record counts) the way native Session Replay would.
///
/// Only registered when no native Session Replay is present. It conforms to no Session Replay
/// protocol, so native code looking the native feature up by type still finds none, and enabling
/// native Session Replay later replaces it.
internal final class SessionReplayContextFeature: DatadogFeature {
    static let name = Feature.sessionReplay

    let messageReceiver: FeatureMessageReceiver = NOPFeatureMessageReceiver()
}
