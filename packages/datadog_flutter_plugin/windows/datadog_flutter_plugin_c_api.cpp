#include "include/datadog_flutter_plugin/datadog_flutter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "datadog_flutter_plugin.h"

void DatadogFlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  datadog_flutter_plugin::DatadogFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
