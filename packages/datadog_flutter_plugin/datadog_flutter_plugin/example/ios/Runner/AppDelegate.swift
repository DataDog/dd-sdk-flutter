// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import UIKit
import Flutter
import DatadogRUM

enum InternalError: Error {
    case pluginError
}

@main
@objc class AppDelegate: FlutterAppDelegate {
    var methodChannel: FlutterMethodChannel!

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        let crashPluginRegistry = registrar(forPlugin: "ExampleCrashPlugin")!
        registerCrashPlugin(with: crashPluginRegistry)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    @objc func registerCrashPlugin(with registrar: FlutterPluginRegistrar) {
        methodChannel = FlutterMethodChannel(name: "datadog_sdk_flutter.example.crash",
                                             binaryMessenger: registrar.messenger())
        methodChannel.setMethodCallHandler { call, result in
            // swiftlint:disable:next force_try
            try! self.handle(methodCall: call, result: result)
        }
    }

    func handle(methodCall: FlutterMethodCall, result: FlutterResult) throws {
        switch methodCall.method {
        case "crashNative":
            let crashValue: Int? = nil
            _ = crashValue! + 5

        case "throwException":
            throw InternalError.pluginError

        case "performCallback":
            let arguments = methodCall.arguments as! [String: Any?]
            let callbackId = arguments["callbackId"] as! Int
            let callArguments: [String: Any] = [
                "callbackId": callbackId,
                "callbackValue": "Value String"
            ]

            methodChannel.invokeMethod("nativeCallback", arguments: callArguments) { callbackResult in
                switch callbackResult {
                case let error as FlutterError:
                    RUMMonitor.shared().addError(
                        message: error.message ?? "Unknown Dart Error",
                        stack: nil,
                        source: RUMErrorSource.source,
                        attributes: [
                            "errorCode": error.code
                        ]
                    )
                default:
                    break
                }
            }

        default:
            break
        }

        result(nil)
    }
}
