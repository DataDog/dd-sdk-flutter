// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import Foundation
import DatadogInternal

internal struct WebViewRecordReceiver: FeatureMessageReceiver {
    internal struct WebRecord: Encodable {
        /// The RUM application ID of all records.
        let applicationID: String
        /// The RUM session ID of all records.
        let sessionID: String
        /// The RUM view ID of all records.
        let viewID: String
        /// Records enriched with further information.
        let records: [AnyEncodable]
    }

    /// Flutter Session Replay feature scope.
    let scope: FeatureScope

    func receive(message: FeatureMessage, from core: DatadogCoreProtocol) -> Bool {
        guard case let .webview(.record(event, view)) = message else {
            return false
        }

        // In hybrid apps the native Session Replay feature receives the same message and owns WebView
        // records; writing them here too would upload every record twice.
        guard !core.isNativeSessionReplayRegistered else {
            return false
        }

        scope.eventWriteContext { context, writer in
            // Extract the `RUMContext` or `nil` if RUM session is not sampled:
            guard
                let rumContext = context.additionalContext(ofType: RUMCoreContext.self),
                rumContext.sessionSampler.isSampled
            else {
                return
            }

            // Flutter Session Replay publishes `has_replay` only while it records a session its
            // `replaySampleRate` selected, so this keeps WebView records out of the other sessions.
            guard context.additionalContext(ofType: SessionReplayCoreContext.HasReplay.self)?.value == true else {
                return
            }

            var event = event

            if let timestamp = event["timestamp"] as? Int,
               let webViewContext = context.additionalContext(ofType: RUMWebViewContext.self),
               let offset = webViewContext.serverTimeOffset(forView: view.id) {
                event["timestamp"] = Int64(timestamp) + offset.dd.toInt64Milliseconds
            }

            let record = WebRecord(
                applicationID: rumContext.applicationID,
                sessionID: rumContext.sessionID,
                viewID: view.id,
                records: [AnyEncodable(event)]
            )

            writer.write(value: record)
        }

        return true
    }
}
