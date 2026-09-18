import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'datadog_inappwebview_tracking_method_channel.dart';

abstract class DatadogInAppWebViewTrackingPlatform extends PlatformInterface {
  DatadogInAppWebViewTrackingPlatform() : super(token: _token);

  static final Object _token = Object();

  static DatadogInAppWebViewTrackingPlatform _instance =
      MethodChannelDatadogInAppWebViewTracking();

  /// The default instance of [DatadogInAppWebViewTrackingPlatform] to use.
  ///
  /// Defaults to [MethodChannelDatadogInAppWebViewTracking].
  static DatadogInAppWebViewTrackingPlatform get instance => _instance;
  static set instance(DatadogInAppWebViewTrackingPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> sendWebViewMessage(String message, double logSampleRate);
}
