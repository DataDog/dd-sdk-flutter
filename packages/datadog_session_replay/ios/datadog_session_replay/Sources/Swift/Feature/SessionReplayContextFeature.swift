// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import Foundation
import DatadogInternal

/// Stands in for the native Session Replay feature under its name when Flutter Session Replay runs
/// standalone, as the Android plugin does, so that Flutter owns the replay state it publishes
/// (`has_replay`, record counts) the way native Session Replay would.
///
/// It conforms to `SessionReplayConfiguration` because `WebViewTracking` only shares the `records`
/// capability (and the privacy level) with the Browser SDK when it finds a feature of that type under
/// the native Session Replay name. The WebView records this enables are broadcast on the message bus
/// and written by Flutter Session Replay's `WebViewRecordReceiver`; this feature receives nothing.
///
/// Only registered when no native Session Replay is present, and enabling native Session Replay later
/// replaces it. Code telling the two apart must check for this type explicitly.
internal final class SessionReplayContextFeature: DatadogFeature, SessionReplayConfiguration {
    static let name = Feature.sessionReplay

    let messageReceiver: FeatureMessageReceiver = NOPFeatureMessageReceiver()

    let textAndInputPrivacyLevel: TextAndInputPrivacyLevel
    let imagePrivacyLevel: ImagePrivacyLevel
    let touchPrivacyLevel: TouchPrivacyLevel

    init(configuration: SessionReplayConfiguration) {
        self.textAndInputPrivacyLevel = configuration.textAndInputPrivacyLevel
        self.imagePrivacyLevel = configuration.imagePrivacyLevel
        self.touchPrivacyLevel = configuration.touchPrivacyLevel
    }
}

extension DatadogCoreProtocol {
    /// Whether the native Session Replay feature is registered, as opposed to Flutter Session Replay's
    /// `SessionReplayContextFeature` standing in for it.
    var isNativeSessionReplayRegistered: Bool {
        guard let feature = feature(named: Feature.sessionReplay, type: SessionReplayConfiguration.self) else {
            return false
        }
        return !(feature is SessionReplayContextFeature)
    }
}
