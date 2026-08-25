// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import Foundation
import DatadogCore
import DatadogInternal

// Force symbols to be retained during linking
@_silgen_name("__datadog_session_replay_keep_symbols")
// swiftlint:disable:next identifier_name
public func __datadog_session_replay_keep_symbols() {
    // Reference all classes to prevent dead code elimination
    _ = FlutterRUMCoreContext.self
    _ = FlutterSessionReplayConfiguration.self
    _ = FlutterSessionReplay.self
}

@objc(FlutterRUMCoreContext) public class FlutterRUMCoreContext: NSObject {
    @objc public var sessionID: String
    @objc public var viewID: String?
    @objc public var applicationID: String

    internal init(sessionID: String, viewID: String?, applicationID: String) {
        self.sessionID = sessionID
        self.viewID = viewID
        self.applicationID = applicationID
        super.init()
    }
}

@objc(FlutterSessionReplayConfiguration) public class FlutterSessionReplayConfiguration: NSObject {
    @objc public var customEndpoint: URL?

    public var onContextChanged: ((FlutterRUMCoreContext?) -> Void)?

    @objc public init(
        customEndpoint: URL? = nil,
        onContextChanged: ((FlutterRUMCoreContext?) -> Void)? = nil
    ) {
        self.customEndpoint = customEndpoint
        self.onContextChanged = onContextChanged
        super.init()
    }
}

@objc(FlutterSessionReplay) public class FlutterSessionReplay: NSObject {
    // Static properties so the callback and feature survive engine detach/re-attach cycles,
    // mirroring the Android FlutterSessionReplayBridge singleton pattern.
    internal static var contextCallback: ((FlutterRUMCoreContext?) -> Void)?
    internal static var feature: FlutterSessionReplayFeature?

    // Ownership token for multi-engine support: only the engine that called enable()
    // is allowed to null out the callback on detach. Set by claimOwnership(messenger:)
    // after the Dart-side method channel message is delivered.
    internal static var listenerOwner: AnyObject?

    static func claimOwnership(messenger: AnyObject) {
        listenerOwner = messenger
    }

    @objc public func enable(with configuration: FlutterSessionReplayConfiguration) {
        do {
            try enableOrThrow(with: configuration, in: CoreRegistry.default)
        } catch let error {
            consolePrint("\(error)", .error)
        }
    }

    internal func enableOrThrow(
        with configuration: FlutterSessionReplayConfiguration,
        in core: DatadogCoreProtocol
    ) throws {
        guard !(core is NOPDatadogCore) else {
            throw ProgrammerError(
                description: "Datadog SDK must be initialized before calling `SessionReplay.enable(with:)`."
            )
        }

        // Always replace the context callback to prevent a crash on Hot Restart / engine
        // re-attach, where the previously created FFI callback has been destroyed.
        FlutterSessionReplay.contextCallback = configuration.onContextChanged
        // Clear any stale ownership. claimOwnership(messenger:) will re-establish it for
        // the correct engine once the Dart-side 'claimOwnership' method channel message
        // is delivered. There is a brief gap between enable() and claimOwnership() during
        // which listenerOwner is nil; this is intentional and acceptable — see the comment
        // in DatadogSessionReplayPlugin.register(with:) for the full explanation.
        FlutterSessionReplay.listenerOwner = nil

        // If already initialized, reuse the existing feature (don't re-register with core).
        if FlutterSessionReplay.feature != nil {
            return
        }

        let mappedConfiguration = DefaultFlutterSessionReplayFeature.Configuration(
            customEndpoint: configuration.customEndpoint,
            onContextChanged: { context in
                // Read contextCallback at call time so that nullifying it on engine detach
                // makes this a no-op, preventing calls into a destroyed Dart isolate.
                if let context = context {
                    FlutterSessionReplay.contextCallback?(FlutterRUMCoreContext(
                        sessionID: context.sessionID,
                        viewID: context.viewID,
                        applicationID: context.applicationID
                    ))
                } else {
                    FlutterSessionReplay.contextCallback?(nil)
                }
            }
        )

        let sessionReplay = try DefaultFlutterSessionReplayFeature(
            core: core,
            configuration: mappedConfiguration,
            resourceResolver: nil   // Use the default resource resolver
        )
        try core.register(feature: sessionReplay)
        FlutterSessionReplay.feature = sessionReplay
    }

    /// Nullifies the context callback if the detaching engine is the one that registered it.
    /// This prevents a secondary engine's detach from clearing a live engine's callback.
    static func detachFromEngine(messenger: AnyObject) {
        if listenerOwner === messenger {
            contextCallback = nil
            listenerOwner = nil
        }
    }

    // Only used in testing
    internal static func shutdown() {
        feature = nil
        contextCallback = nil
        listenerOwner = nil
    }

    @objc public func setHasReplay(hasReplay: Bool) {
        FlutterSessionReplay.feature?.setHasReplay(hasReplay)
    }

    @objc public func setRecordCount(for viewId: String, count: Int) {
        FlutterSessionReplay.feature?.setRecordCount(for: viewId, count: Int64(count))
    }

    @objc public func writeSegment(segment segmentJson: String) {
        FlutterSessionReplay.feature?.writeSegment(segment: segmentJson)
    }

    @objc public func postTelemetryDebug(id: String, message: String) {
        Datadog._internal.telemetry.debug(id: "datadog_flutter:\(id)", message: message)
    }

    @objc public func postTelemetryError(message: String, kind: String, stackTrace: String) {
        Datadog._internal.telemetry.error(id: "datadog_flutter:\(String(describing: kind)):\(message)",
                                          message: message, kind: kind, stack: stackTrace)
    }

    @objc public func saveImageForProcessing(resourceKey: Int, width: Int, height: Int, data: Data) {
        FlutterSessionReplay.feature?.resourceResolver.addResource(withKey: resourceKey, width: width, height: height, data: data)
    }

    @objc public func resourceId(forKey key: Int) -> String? {
        return FlutterSessionReplay.feature?.resourceResolver.resolveResource(withKey: key)
    }
}
