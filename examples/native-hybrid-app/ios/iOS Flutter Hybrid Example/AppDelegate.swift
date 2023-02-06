// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import UIKit
import Datadog
import Flutter
import FlutterPluginRegistrant

class FlutterExcludingRumViewsPredicate: UIKitRUMViewsPredicate {
    let defaultViewsPredicate = DefaultUIKitRUMViewsPredicate()
    
    func rumView(for viewController: UIViewController) -> RUMView? {
        if (viewController is FlutterViewController) {
            if #available(iOS 13, *) {
                return nil
            } else {
                return .init(name: "FLutterViewController", isUntrackedModal: true)
            }
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
        
        Datadog.verbosityLevel = .debug
        Datadog.initialize(
            appContext: .init(),
            trackingConsent: .granted,
            configuration: Datadog.Configuration
                .builderUsing(
                    rumApplicationID: rumApplicationId,
                    clientToken: clientToken,
                    environment: "prod"
                )
                .set(endpoint: .us1)
                .trackUIKitRUMViews(using: FlutterExcludingRumViewsPredicate())
                .trackUIKitRUMActions()
                .trackURLSession()
                .build()
        )
        Global.rum = RUMMonitor.initialize()
        
        // Note: Datadog needs to be initialized before flutterEngine.run(), as this will call
        // main() which will look for an existing Datadog instance to attach to.
        flutterEngine.run();
        GeneratedPluginRegistrant.register(with: self.flutterEngine);
        
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        
    }
}
