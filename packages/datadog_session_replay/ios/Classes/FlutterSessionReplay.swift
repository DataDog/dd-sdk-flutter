// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Foundation
import DatadogInternal

class FlutterSessionReplay {
    public struct Configuration {
        public var customEndpoint: URL?

        public init(
            customEndpoint: URL? = nil
        ) {
            self.customEndpoint = customEndpoint
        }
    }

    public static func enable(
        with configuration: FlutterSessionReplay.Configuration,
        in core: DatadogCoreProtocol = CoreRegistry.default
    ) {
        do {
            try enableOrThrow(with: configuration, in: core)
        } catch let error {
            consolePrint("\(error)")
        }
    }

    internal static func enableOrThrow(
        with configuration: FlutterSessionReplay.Configuration,
        in core: DatadogCoreProtocol
    ) throws {
        guard !(core is NOPDatadogCore) else {
            throw ProgrammerError(
                description: "Datadog SDK must be initialized before calling `SessionReplay.enable(with:)`."
            )
        }

        let sessionReplay = try FlutterSessionReplayFeature(core: core, configuration: configuration)
        try core.register(feature: sessionReplay)

//        sessionReplay.writer.startWriting(to: core)
    }
}
