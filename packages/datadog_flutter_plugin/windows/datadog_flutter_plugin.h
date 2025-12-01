#ifndef FLUTTER_PLUGIN_DATADOG_FLUTTER_PLUGIN_H_
#define FLUTTER_PLUGIN_DATADOG_FLUTTER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace datadog_flutter_plugin {

class DatadogFlutterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  DatadogFlutterPlugin();

  virtual ~DatadogFlutterPlugin();

  // Disallow copy and assign.
  DatadogFlutterPlugin(const DatadogFlutterPlugin&) = delete;
  DatadogFlutterPlugin& operator=(const DatadogFlutterPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace datadog_flutter_plugin

#endif  // FLUTTER_PLUGIN_DATADOG_FLUTTER_PLUGIN_H_
