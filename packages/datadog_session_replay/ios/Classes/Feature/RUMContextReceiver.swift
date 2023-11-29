// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Foundation
import DatadogInternal

/// An observer notifying on`RUMContext` changes.
internal protocol RUMContextObserver {
    /// Starts notifying on distinct changes to `RUMContext`.
    ///
    /// - Parameters:
    ///   - queue: a queue to call `notify` block on
    ///   - notify: a closure receiving new `RUMContext` or `nil` if current RUM session is not sampled
    func observe(notify: @escaping (RUMContext?) -> Void)
}

/// Receives RUM context from `DatadogCore` and notifies it through `RUMContextObserver` interface.
internal class RUMContextReceiver: FeatureMessageReceiver, RUMContextObserver {
    /// Notifies new `RUMContext` or `nil` if current RUM session is not sampled.
    private var onNew: ((RUMContext?) -> Void)?
    private var previous: RUMContext?

    // MARK: - FeatureMessageReceiver

    func receive(message: FeatureMessage, from core: DatadogCoreProtocol) -> Bool {
        guard case let .context(context) = message else {
            return false
        }

        var new: RUMContext? = nil

        do {
            // Extract the `RUMContext` or `nil` if RUM session is not sampled:
            new = try context.baggages[RUMContext.key].map { try $0.decode() }
        } catch {
            core.telemetry
                .error("Fails to decode RUM context from Session Replay", error: error)
        }

        // Notify only if it has changed:
        if new != previous {
            onNew?(new)
            previous = new
        }

        return true
    }

    func observe(notify: @escaping (RUMContext?) -> Void) {
        onNew = { new in
            notify(new)
        }
    }
}
