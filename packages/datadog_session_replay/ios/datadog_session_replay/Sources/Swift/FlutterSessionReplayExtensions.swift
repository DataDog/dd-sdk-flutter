// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import Flutter
import UIKit

public extension FlutterViewController {
    /// Registers this view controller with the Datadog Session Replay plugin so that
    /// the SDK can stitch Flutter wireframes into the native Session Replay recording.
    ///
    /// Call this after creating the `FlutterViewController`, before presenting it:
    ///
    /// ```swift
    /// let flutterVC = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    /// flutterVC.enableDatadogSessionReplay()
    /// present(flutterVC, animated: true)
    /// ```
    ///
    /// This stores the view's hash (the slotId) keyed on the engine messenger so the
    /// plugin can retrieve it when the Dart side asks for it on the first frame.
    func enableDatadogSessionReplay() {
        FlutterSessionReplay.registerSlotId(String(view.hash), for: engine.binaryMessenger)
    }
}
