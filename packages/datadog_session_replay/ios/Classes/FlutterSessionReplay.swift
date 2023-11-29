// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Foundation
import DatadogInternal

internal class FlutterSessionReplay {
    public struct Configuration {
        public var customEndpoint: URL?

        public init(
            customEndpoint: URL? = nil
        ) {
            self.customEndpoint = customEndpoint
        }

        public init?(fromEncoded encoded: [String: Any?]) {
            var customEndpoint: URL?
            if let customEndpointString = encoded["customEndpoint"] as? String {
                customEndpoint = URL(string: customEndpointString)
            }

            self.init(customEndpoint: customEndpoint)
        }
    }

    public static func enable(
        with configuration: FlutterSessionReplay.Configuration,
        in core: DatadogCoreProtocol = CoreRegistry.default
    ) -> FlutterSessionReplayFeature? {
        do {
            let feature = try enableOrThrow(with: configuration, in: core)
            return feature
        } catch let error {
            consolePrint("\(error)")
        }
        return nil
    }

    internal static func enableOrThrow(
        with configuration: FlutterSessionReplay.Configuration,
        in core: DatadogCoreProtocol
    ) throws -> FlutterSessionReplayFeature {
        guard !(core is NOPDatadogCore) else {
            throw ProgrammerError(
                description: "Datadog SDK must be initialized before calling `SessionReplay.enable(with:)`."
            )
        }

        let sessionReplay = try FlutterSessionReplayFeature(core: core, configuration: configuration)
        try core.register(feature: sessionReplay)
        
        sessionReplay.writer.startWriting(to: core)
        
        return sessionReplay
    }
}
