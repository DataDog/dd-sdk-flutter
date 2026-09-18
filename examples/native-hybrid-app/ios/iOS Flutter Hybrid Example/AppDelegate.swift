// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import UIKit
import DatadogCore
import DatadogCrashReporting
import DatadogLogs
import DatadogRUM
import Flutter
import FlutterPluginRegistrant

class FlutterExcludingRumViewsPredicate: UIKitRUMViewsPredicate {
    let defaultViewsPredicate = DefaultUIKitRUMViewsPredicate()

    func rumView(for viewController: UIViewController) -> RUMView? {
        if viewController is FlutterViewController {
            return nil
        }

        return defaultViewsPredicate.rumView(for: viewController)
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    lazy var flutterEngine = FlutterEngine(name: "my flutter engine")
    var dismissMethodChannel: FlutterMethodChannel!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        var clientToken = ""
        var rumApplicationId = ""

        if let configFile = Bundle.main.path(forResource: "ddog_config", ofType: "plist"),
           let dataodogKeys = NSDictionary(contentsOfFile: configFile) {
            clientToken = dataodogKeys["client_token"] as? String ?? ""
            rumApplicationId = dataodogKeys["application_id"] as? String ?? ""
        } else {
            print("Failed to find client token and application in ddog_config.plist." +
                  " Did you run './generate_env'?")
        }

        // If you are adding Flutter to an existing iOS application, you should
        // ensure Datadog is fully initialized on the iOS side before
        // initializing Flutter and calling `DatadogSdk.attachToExisting`.
        // For more information about how to setup Datadog in iOS, see the official
        // documentation:
        // https://docs.datadoghq.com/real_user_monitoring/mobile_and_tv_monitoring/ios/setup/
        let coreConfig = Datadog.Configuration(
            clientToken: clientToken,
            env: "prod")
        Datadog.verbosityLevel = .debug
        Datadog.initialize(with: coreConfig, trackingConsent: TrackingConsent.granted)

        // All components you want to use in Flutter must be initialized on iOS first. 
        // This includes Logs...
        Logs.enable()

        // ... RUM...
        let rumConfig = RUM.Configuration(applicationID: rumApplicationId, uiKitViewsPredicate: FlutterExcludingRumViewsPredicate())
        RUM.enable(with: rumConfig)

        // ... and CrashReporting.
        CrashReporting.enable()

        // Once Datadog is fully initialized, you can run `flutterEngine.run()`.
        // This calls Flutter's `main` method, which will look for an existing Datadog instance to attach to.
        flutterEngine.run()
        GeneratedPluginRegistrant.register(with: self.flutterEngine)

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {

    }
}
