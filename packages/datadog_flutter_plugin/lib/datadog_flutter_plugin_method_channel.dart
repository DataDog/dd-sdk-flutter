import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'datadog_flutter_plugin_platform_interface.dart';

/// An implementation of [DatadogFlutterPluginPlatform] that uses method channels.
class MethodChannelDatadogFlutterPlugin extends DatadogFlutterPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('datadog_flutter_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
