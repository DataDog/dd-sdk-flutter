/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2024-Present Datadog, Inc.
 */

import Flutter
import UIKit
import DatadogCore
import DatadogInternal

public class DatadogInAppWebViewTrackingPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "datadog_inappwebview_tracking",
                                           binaryMessenger: registrar.messenger())
        let instance = DatadogInAppWebViewTrackingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let core = CoreRegistry.default

        switch call.method {
        case "webViewMessage":
            guard let arguments = call.arguments as? [String: Any] else {
                result(
                    FlutterError.invalidOperation(message: "No arguments in call to \(call.method)")
                )
                return
            }

            guard let messageBody: String = arguments["message"] as? String,
                  let logSampleRate = (arguments["logSampleRate"] as? NSNumber)?.floatValue else {
                result(FlutterError.missingParameter(methodName: call.method))
                return
            }

            do {
                guard let data = messageBody.data(using: .utf8) else {
                    throw WebViewMessageError.dataSerialization(message: messageBody)
                }

                let decoder = JSONDecoder()
                let message = try decoder.decode(WebViewMessage.self, from: data)

                switch message {
                case .log:
                    send(log: message, sampleRate: logSampleRate, in: core)
                case .rum, .telemetry:
                    send(rum: message, in: core)
                default:
                    throw WebViewMessageError.invalidMessage(description: String(describing: message))
                }
            } catch {
                DD.logger.error("Encountered an error when receiving web view event", error: error)
                core.telemetry.error("Encountered an error when receiving web view event", error: error)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func send(log message: WebViewMessage, sampleRate: Float, in core: DatadogCoreProtocol) {
        guard Float.random(in: 0.0..<100.0) < sampleRate else {
            return
        }

        core.send(message: .webview(message), else: {
            DD.logger.warn("A WebView log is lost because Logging is disabled in the SDK")
        })
    }

    private func send(rum message: WebViewMessage, in core: DatadogCoreProtocol) {
        core.send(message: .webview(message), else: {
            DD.logger.warn("A WebView RUM event is lost because RUM is disabled in the SDK")
        })
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

enum WebViewMessageError: Error, Equatable {
    case dataSerialization(message: String)
    case invalidMessage(description: String)
}
