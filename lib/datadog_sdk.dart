import 'package:datadog_sdk/datadog_sdk_platform_interface.dart';

class DdSdkConfiguration {
  final String clientToken;
  final String env;
  final String? applicationId;
  final bool nativeCrashReportEnabled;
  final double sampleRate;
  final String? site;
  final String? trackingConsent;
  final Map<String, dynamic> additionalConfig;

  DdSdkConfiguration(
      {required this.clientToken,
      required this.env,
      this.applicationId,
      this.nativeCrashReportEnabled = false,
      this.sampleRate = 100.0,
      this.site,
      this.trackingConsent,
      this.additionalConfig = const {}});

  Map<String, dynamic> encode() {
    return {
      'clientToken': clientToken,
      'env': env,
      'applicationId': applicationId,
      'nativeCrashReportEnabled': nativeCrashReportEnabled,
      'sampleRate': sampleRate,
      'site': site,
      'trackingConsent': trackingConsent,
      'additionaliConfig': additionalConfig
    };
  }
}

class DatadogSdk {
  static DatadogSdkPlatform get _platform {
    return DatadogSdkPlatform.instance;
  }

  static DatadogSdk? _singleton;
  factory DatadogSdk() {
    _singleton ??= DatadogSdk._();
    return _singleton!;
  }

  DatadogSdk._();

  Future<void> initialize(DdSdkConfiguration configuration) {
    return _platform.initialize(configuration);
  }

  DdLogs get ddLogs => _platform.ddLogs;
}
