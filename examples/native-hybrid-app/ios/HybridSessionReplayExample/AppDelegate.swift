// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import UIKit
import DatadogCore
import DatadogLogs
import DatadogRUM
import DatadogSessionReplay
import Flutter
import FlutterPluginRegistrant

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    /// Runs `main`: the full screen Flutter view pushed on top of the native screen.
    lazy var flutterEngine = FlutterEngine(name: "main_flutter_engine")
    /// Runs `embeddedMain`: the Flutter panel embedded in the native screen.
    lazy var embeddedFlutterEngine = FlutterEngine(name: "embedded_flutter_engine")

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        var clientToken = ""
        var rumApplicationId = ""

        if let configFile = Bundle.main.path(forResource: "ddog_config", ofType: "plist"),
           let datadogKeys = NSDictionary(contentsOfFile: configFile) {
            clientToken = datadogKeys["client_token"] as? String ?? ""
            rumApplicationId = datadogKeys["application_id"] as? String ?? ""
        } else {
            print("Failed to find client token and application id in ddog_config.plist." +
                  " Did you run './generate_env.sh'?")
        }

        // Datadog must be fully initialized on the iOS side, including Session Replay, before
        // any Flutter engine runs `main` and calls `DatadogSdk.attachToExisting`.
        Datadog.verbosityLevel = .debug
        Datadog.initialize(
            with: Datadog.Configuration(clientToken: clientToken, env: "prod", site: .us1),
            trackingConsent: .granted
        )

        Logs.enable()

        // Each FlutterViewController is tracked as its own RUM view, so the full screen Flutter
        // view gets its own view in the replay.
        RUM.enable(with: RUM.Configuration(
            applicationID: rumApplicationId,
            uiKitViewsPredicate: DefaultUIKitRUMViewsPredicate(),
            uiKitActionsPredicate: DefaultUIKitRUMActionsPredicate()
        ))

        // The native Session Replay records the whole app, Flutter included. Its sample rate
        // decides which sessions get a replay; the Flutter side's `replaySampleRate` is ignored.
        // The privacy levels are not shared, so the Dart side sets the same ones.
        SessionReplay.enable(
            with: SessionReplay.Configuration(
                replaySampleRate: 100,
                textAndInputPrivacyLevel: .maskSensitiveInputs,
                imagePrivacyLevel: .maskNone,
                touchPrivacyLevel: .show
            )
        )

        flutterEngine.run()
        GeneratedPluginRegistrant.register(with: flutterEngine)

        embeddedFlutterEngine.run(withEntrypoint: "embeddedMain")
        GeneratedPluginRegistrant.register(with: embeddedFlutterEngine)

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
