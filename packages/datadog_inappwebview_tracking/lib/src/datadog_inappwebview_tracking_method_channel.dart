import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'datadog_inappwebview_tracking_platform_interface.dart';

/// An implementation of [DatadogInAppWebViewTrackingPlatform] that uses method channels.
class MethodChannelDatadogInAppWebViewTracking
    extends DatadogInAppWebViewTrackingPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('datadog_inappwebview_tracking');

  @override
  Future<void> sendWebViewMessage(String message, double logSampleRate) async {
    methodChannel.invokeMethod('webViewMessage', {
      'message': message,
      'logSampleRate': logSampleRate,
    });
  }
}
