// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import Flutter

/// A messenger that does nothing.
///
/// The slot-ID registry only ever uses a messenger as an identity key, so none of the message
/// passing needs to work — the tests just need two distinguishable messenger objects.
class FlutterBinaryMessengerMock: NSObject, FlutterBinaryMessenger {
    func send(onChannel channel: String, message: Data?) { }

    func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply? = nil) { }

    func setMessageHandlerOnChannel(
        _ channel: String,
        binaryMessageHandler handler: FlutterBinaryMessageHandler? = nil
    ) -> FlutterBinaryMessengerConnection {
        return 0
    }

    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) { }
}

/// Stands in for `FlutterBinaryMessengerRelay`, which Flutter wraps around the real engine
/// messenger.
///
/// `registrar.messenger()` and `engine.binaryMessenger` hand back *different* relay instances for
/// the same engine, so the registry keys on the relay's `parent` instead. The real relay type is
/// private, so `canonical(_:)` reaches `parent` through KVC — which is why this mock exposes it as
/// an `@objc` property rather than a plain Swift one.
class FlutterBinaryMessengerRelayMock: FlutterBinaryMessengerMock {
    @objc let parent: NSObject

    init(parent: NSObject) {
        self.parent = parent
        super.init()
    }
}
