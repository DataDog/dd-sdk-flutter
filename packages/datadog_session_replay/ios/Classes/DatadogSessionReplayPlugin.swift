import Flutter
import UIKit

public class DatadogSessionReplayPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "datadog_sdk_flutter.session_replay", binaryMessenger: registrar.messenger())
    let instance = DatadogSessionReplayPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "enable":
      enableSessionReplay()
    default:
      result(FlutterMethodNotImplemented)
    }
  }

    private func enableSessionReplay() {

    }
}
