import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    var methodChannel: FlutterMethodChannel!

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        methodChannel = FlutterMethodChannel(name: "com.datadog.crash_channel",
                                                    binaryMessenger: engineBridge.applicationRegistrar.messenger())
        methodChannel.setMethodCallHandler { call, result in
            try? self.handle(methodCall: call, result: result)
        }
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
