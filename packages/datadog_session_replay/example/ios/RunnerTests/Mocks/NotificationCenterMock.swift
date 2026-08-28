// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
@testable import datadog_session_replay

/// A `NotificationCenter` stand-in that never broadcasts process-wide: `post(name:)` only invokes
/// observers registered on this instance, so driving termination in a test cannot tear down another
/// suite's engine or the Runner's own registered plugin.
class NotificationCenterMock: NotificationCenterProtocol {
    private var observers: [(observer: NSObject, selector: Selector, name: NSNotification.Name?)] = []

    func addObserver(_ observer: Any, selector: Selector, name: NSNotification.Name?, object: Any?) {
        guard let observer = observer as? NSObject else { return }
        observers.append((observer, selector, name))
    }

    func removeObserver(_ observer: Any) {
        guard let observer = observer as? NSObject else { return }
        observers.removeAll { $0.observer === observer }
    }

    func post(name: NSNotification.Name) {
        for entry in observers where entry.name == name {
            entry.observer.perform(entry.selector)
        }
    }
}
