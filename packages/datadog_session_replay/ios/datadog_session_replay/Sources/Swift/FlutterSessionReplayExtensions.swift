// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import Flutter
import UIKit
import DatadogInternal

extension FlutterViewController: DatadogExtended {}

public extension DatadogExtension where ExtendedType: FlutterViewController {
    /// Registers this view controller with the Datadog Session Replay plugin so that
    /// the SDK can stitch Flutter wireframes into the native Session Replay recording.
    ///
    /// Call this after creating the `FlutterViewController`, before presenting it, and after
    /// native Session Replay recording has started:
    ///
    /// ```swift
    /// let flutterVC = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    /// flutterVC.dd.enableSessionReplay()
    /// present(flutterVC, animated: true)
    /// ```
    ///
    /// This assigns a slot ID to the view — the identifier the native recorder reads back to
    /// emit the `embedded_view` placeholder — and keys this view controller on the engine
    /// messenger so the plugin can resolve that ID when the Dart side asks for it on the
    /// first frame.
    ///
    /// The view is not yet attached to a window at this point, so the assignment is recorded
    /// as a pending layout change rather than triggering a snapshot immediately. Because native
    /// Session Replay is already recording, that pending layout is observed as soon as the view
    /// is attached when the view controller is presented, and the slot is captured without
    /// waiting for an unrelated screen change.
    ///
    /// Calling this more than once for the same view controller is safe: the slot ID is
    /// assigned only if the view does not already have one.
    func enableSessionReplay() {
        FlutterSessionReplayManager.shared.registerSlot(for: type, messenger: type.engine.binaryMessenger)
    }
}
