// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
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
      let channel = FlutterMethodChannel(name: "datadog_sdk_flutter.example.crash",
                                         binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { _, result in
        let crashValue: Int? = nil
        _ = crashValue! + 5

        result(nil)
      }
    }
}
