import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'datadog_session_replay_method_channel.dart';

abstract class DatadogSessionReplayPlatform extends PlatformInterface {
  /// Constructs a DatadogSessionReplayPlatform.
  DatadogSessionReplayPlatform() : super(token: _token);

  static final Object _token = Object();

  static DatadogSessionReplayPlatform _instance =
      MethodChannelDatadogSessionReplay();

  /// The default instance of [DatadogSessionReplayPlatform] to use.
  ///
  /// Defaults to [MethodChannelDatadogSessionReplay].
  static DatadogSessionReplayPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DatadogSessionReplayPlatform] when
  /// they register themselves.
  static set instance(DatadogSessionReplayPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }
}
