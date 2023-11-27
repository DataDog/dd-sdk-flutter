import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'datadog_session_replay_platform_interface.dart';

/// An implementation of [DatadogSessionReplayPlatform] that uses method channels.
class MethodChannelDatadogSessionReplay extends DatadogSessionReplayPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel =
      const MethodChannel('datadog_sdk_flutter.session_replay');
}
