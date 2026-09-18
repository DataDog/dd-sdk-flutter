import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    var methodChannel: FlutterMethodChannel!

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        methodChannel = FlutterMethodChannel(name: "com.datadog.crash_channel",
                                                    binaryMessenger: controller.binaryMessenger)
        methodChannel.setMethodCallHandler { call, result in
            try! self.handle(methodCall: call, result: result)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func handle(methodCall: FlutterMethodCall, result: FlutterResult) throws {
        switch methodCall.method {
        case "crash":
            let crashValue: Int? = nil
            _ = crashValue! + 5
        default:
            break
        }

        result(nil)
    }
}
