import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'datadog_flutter_plugin_method_channel.dart';

abstract class DatadogFlutterPluginPlatform extends PlatformInterface {
  /// Constructs a DatadogFlutterPluginPlatform.
  DatadogFlutterPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static DatadogFlutterPluginPlatform _instance = MethodChannelDatadogFlutterPlugin();

  /// The default instance of [DatadogFlutterPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelDatadogFlutterPlugin].
  static DatadogFlutterPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DatadogFlutterPluginPlatform] when
  /// they register themselves.
  static set instance(DatadogFlutterPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
