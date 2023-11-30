// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Flutter
import UIKit

public class DatadogSessionReplayPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "datadog_sdk_flutter.session_replay", binaryMessenger: registrar.messenger())
        let instance = DatadogSessionReplayPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    let channel: FlutterMethodChannel
    var feature: FlutterSessionReplayFeature?

    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any?] else {
            result(
                FlutterError.invalidOperation(message: "No arguments in call to \(call.method)")
            )
            return
        }

        switch call.method {
        case "enable":
            enableSessionReplay(argumnets: arguments, result: result)
        case "setHasReplay":
            setHasReplay(arguments: arguments, result: result)
        case "setRecordCount":
            setRecordCount(arguments: arguments, result: result)
        case "writeSegment":
            writeSegment(arguments: arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func enableSessionReplay(argumnets: [String: Any?], result: @escaping FlutterResult) {
        guard let configurationJson = argumnets["configuration"] as? [String: Any?],
              let configuration = FlutterSessionReplay.Configuration(fromEncoded: configurationJson) else {
            result(FlutterError.missingParameter(methodName: "enable"))
            return
        }

        feature = FlutterSessionReplay.enable(with: configuration)
        if let contextReciever = feature?.messageReceiver as? RUMContextReceiver {
            contextReciever.observe(notify: { context in
                self.onContextChanged(rumContext: context)
            })
        }

        // TODO: Error handling

        result(nil)
    }

    private func setHasReplay(arguments: [String: Any?], result: @escaping FlutterResult) {
        guard let hasReplay = arguments["hasReplay"] as? Bool else {
            result(FlutterError.missingParameter(methodName: "setHasReplay"))
            return
        }

        feature?.setHasReplay(hasReplay)

        result(nil)
    }

    private func setRecordCount(arguments: [String: Any?], result: @escaping FlutterResult) {
        guard let viewId = arguments["viewId"] as? String,
              let count = arguments["count"] as? Int else {
            result(FlutterError.missingParameter(methodName: "setRecordCount"))
            return
        }

        feature?.setRecordCount(for: viewId, count: count)

        result(nil)
    }

    private func writeSegment(arguments: [String: Any?], result: @escaping FlutterResult) {
        // TODO: We may want to hand down segments as a byte pointer over strings
        guard let record = arguments["record"] as? String,
              let viewId = arguments["viewId"] as? String else {
            result(FlutterError.missingParameter(methodName: "writeSegment"))
            return
        }

        feature?.writer.write(record: record, viewId: viewId)

        result(nil)
    }

    private func onContextChanged(rumContext: RUMContext?) {
        if let dictionary = rumContext?.encodedForFlutter() {
            DispatchQueue.main.async {
                self.channel.invokeMethod("onContextChanged", arguments: dictionary)
            }
        }
    }
}

extension FlutterError {
    public enum DdErrorCodes {
        static let contractViolation = "DatadogSdk:ContractViolation"
        static let invalidOperation = "DatadogSdk:InvalidOperation"
    }

    static func missingParameter(methodName: String) -> FlutterError {
        return FlutterError(code: DdErrorCodes.contractViolation,
                            message: "Missing parameter in call to \(methodName)",
                            details: nil)
    }

    static func invalidOperation(message: String) -> FlutterError {
        return FlutterError(code: DdErrorCodes.invalidOperation,
                            message: message,
                            details: nil)
    }
}
