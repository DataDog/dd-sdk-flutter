// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation

/// Hands a resource to the native Session Replay.
///
/// Returns `false` when the native side cannot take it — Flutter is not embedded, or no core is
/// known yet — so the caller can fall back to the Flutter-owned `ResourcesFeature`.
internal typealias EmbeddedResourceSink = (_ identifier: String, _ data: Data, _ mimeType: String) -> Bool

/// Writes Session Replay resources to whichever pipeline matches the current embedding.
///
/// When Flutter is embedded, resources go to the native Session Replay over the SDK message bus.
///
/// When Flutter is the host app there is no native Session Replay to hand them to, so they are
/// written to the Flutter feature, as before.
internal final class RoutedResourcesWriter: ResourcesWriting {
    private let standaloneWriter: ResourcesWriting
    private let sendToNative: EmbeddedResourceSink

    init(standaloneWriter: ResourcesWriting, sendToNative: @escaping EmbeddedResourceSink) {
        self.standaloneWriter = standaloneWriter
        self.sendToNative = sendToNative
    }

    func write(withIdentifier identifier: String, data: Data, mimeType: String) {
        guard !sendToNative(identifier, data, mimeType) else {
            return
        }

        standaloneWriter.write(withIdentifier: identifier, data: data, mimeType: mimeType)
    }
}
