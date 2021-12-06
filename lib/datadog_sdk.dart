
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
  
  DdSdkConfiguration({
    required this.clientToken,
    required this.env,
    this.applicationId,
    this.nativeCrashReportEnabled = false,
    this.sampleRate = 100.0,
    this.site,
    this.trackingConsent,
    this.additionalConfig = const {}
  });

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
  final DdSdkConfiguration configuration;

  static DatadogSdkPlatform get _platform {
    return DatadogSdkPlatform.instance;
  }

  DatadogSdk(this.configuration);

  Future<void> initialize() {
    return _platform.initialize(configuration);
  }
}
