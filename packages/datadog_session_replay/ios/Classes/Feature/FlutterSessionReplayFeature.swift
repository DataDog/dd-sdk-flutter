// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Foundation
import DatadogInternal

class FlutterSessionReplayFeature: DatadogRemoteFeature {
    static var name: String = "flutter-session-replay"

    var requestBuilder: DatadogInternal.FeatureRequestBuilder
    var messageReceiver: DatadogInternal.FeatureMessageReceiver
    
    init(
        core: DatadogCoreProtocol,
        configuration: FlutterSessionReplay.Configuration
    ) throws {
        self.requestBuilder = RequestBuilder(
            customUploadURL: configuration.customEndpoint,
            telemetry: core.telemetry
        )
        
        self.messageReceiver = RUMContextReceiver()
    }
}
