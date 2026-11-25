// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

#if os(iOS)
import Foundation
import Flutter

/// A view that can tell when it first displays Flutter UI.
internal protocol FlutterFirstFrameSource: AnyObject {
    var isDisplayingFlutterUI: Bool { get }

    /// Calls `onDisplay` once, the first time the view displays Flutter UI.
    /// - Returns: a token that keeps the observation alive.
    func observeFirstDisplay(_ onDisplay: @escaping () -> Void) -> AnyObject
}

/// Records the time Flutter displays its first frame and reports it, once, for Time to Initial Display (TTID).
///
/// Flutter's first frame is drawn by its engine, after the first native frame, so the time the SDK would detect
/// itself is too early.
internal final class FlutterFirstFrameTracker {
    private let dateProvider: () -> Date
    private var observation: AnyObject?
    private var firstFrameDate: Date?
    private var reporter: ((Date) -> Void)?
    private var hasReported = false

    init(dateProvider: @escaping () -> Date = Date.init) {
        self.dateProvider = dateProvider
    }

    /// Whether the tracker saw the first frame or is waiting for it.
    var canReport: Bool {
        firstFrameDate != nil || observation != nil
    }

    /// Starts waiting for the first frame of `source`.
    ///
    /// Does nothing if the tracker is already waiting for or saw a first frame, or if `source` already displays
    /// Flutter UI, because the time of its first frame is then unknown.
    func observe(_ source: FlutterFirstFrameSource?) {
        guard observation == nil,
              firstFrameDate == nil,
              let source,
              !source.isDisplayingFlutterUI else {
            return
        }
        observation = source.observeFirstDisplay { [weak self] in
            self?.didDisplayFirstFrame()
        }
    }

    /// Reports the first frame time to `reporter`, now if the first frame was displayed, or when it is.
    func report(to reporter: @escaping (Date) -> Void) {
        self.reporter = reporter
        reportIfNeeded()
    }

    private func didDisplayFirstFrame() {
        guard firstFrameDate == nil else {
            return
        }
        firstFrameDate = dateProvider()
        observation = nil
        reportIfNeeded()
    }

    private func reportIfNeeded() {
        guard !hasReported, let firstFrameDate, let reporter else {
            return
        }
        hasReported = true
        self.reporter = nil
        reporter(firstFrameDate)
    }
}

extension FlutterViewController: FlutterFirstFrameSource {
    func observeFirstDisplay(_ onDisplay: @escaping () -> Void) -> AnyObject {
        FirstDisplayObserver(viewController: self, onDisplay: onDisplay)
    }
}

/// Observes `FlutterViewController.displayingFlutterUI`, which is documented as observable, until it becomes `true`.
private final class FirstDisplayObserver: NSObject {
    private static let keyPath = "displayingFlutterUI"

    private var viewController: FlutterViewController?
    private var onDisplay: (() -> Void)?

    init(viewController: FlutterViewController, onDisplay: @escaping () -> Void) {
        self.viewController = viewController
        self.onDisplay = onDisplay
        super.init()
        viewController.addObserver(self, forKeyPath: Self.keyPath, options: [.new], context: nil)
    }

    deinit {
        stopObserving()
    }

    // swiftlint:disable:next block_based_kvo
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == Self.keyPath,
              let observed = object as? FlutterViewController,
              observed === viewController else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        guard observed.isDisplayingFlutterUI, let onDisplay else {
            return
        }
        stopObserving()
        self.onDisplay = nil
        onDisplay()
    }

    private func stopObserving() {
        viewController?.removeObserver(self, forKeyPath: Self.keyPath)
        viewController = nil
    }
}
#endif
