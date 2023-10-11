// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.
// ignore_for_file: unused_element, library_private_types_in_public_api

@JS('DD_RUM')
library ddrum_flutter_web;

import 'package:js/js.dart';

import '../../datadog_flutter_plugin.dart';
import '../logs/ddweb_helpers.dart';
import '../web_helpers.dart';
import 'ddrum_platform_interface.dart';

class DdRumWeb extends DdRumPlatform {
  final Map<String, Object?> currentAttributes = {};

  // Because Web needs the full SDK configuration, we have a separate init method
  void webInitialize(DatadogConfiguration configuration,
      DatadogRumConfiguration rumConfiguration) {
    init(_RumInitOptions(
      applicationId: rumConfiguration.applicationId,
      clientToken: configuration.clientToken,
      site: siteStringForSite(configuration.site),
      sampleRate: rumConfiguration.sessionSamplingRate,
      sessionReplaySampleRate: 0,
      service: configuration.service,
      env: configuration.env,
      version: configuration.versionTag,
      proxyUrl: rumConfiguration.customEndpoint,
      // allowedTracingOrigins: configuration.firstPartyHosts,
      trackViewsManually: true,
      trackFrustrations: rumConfiguration.trackFrustrations,
      trackLongTasks: rumConfiguration.detectLongTasks,
      enableExperimentalFeatures: ['feature_flags'],
    ));
  }

  @override
  Future<void> enable(
      DatadogSdk core, DatadogRumConfiguration configuration) async {}

  @override
  Future<void> addAttribute(String key, dynamic value) async {
    currentAttributes[key] = value;
    _jsSetRumGlobalContext(attributesToJs(currentAttributes, 'context'));
  }

  @override
  Future<void> addError(
    Object error,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, dynamic> attributes,
  ) async {
    var jsError = JSError();
    jsError.stack = convertWebStackTrace(stackTrace);
    jsError.message = error.toString();
    jsError.name = errorType ?? 'Error';

    _jsAddError(jsError, attributesToJs(attributes, 'attributes'));
  }

  @override
  Future<void> addErrorInfo(
    String message,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, dynamic> attributes,
  ) async {
    var jsError = JSError();
    jsError.stack = convertWebStackTrace(stackTrace);
    jsError.message = message;
    jsError.name = errorType ?? 'Error';

    _jsAddError(jsError, attributesToJs(attributes, 'attributes'));
  }

  @override
  Future<void> addTiming(String name) async {
    _jsAddTiming(name);
  }

  @override
  Future<void> addAction(
      RumActionType type, String name, Map<String, dynamic> attributes) async {
    _jsAddAction(name, attributesToJs(attributes, 'attributes'));
  }

  @override
  Future<void> removeAttribute(String key) async {
    currentAttributes.remove(key);
    _jsSetRumGlobalContext(attributesToJs(currentAttributes, 'context'));
  }

  @override
  Future<void> startResource(String key, RumHttpMethod httpMethod, String url,
      Map<String, dynamic> attributes) async {
    // NOOP
  }

  @override
  Future<void> startAction(
      RumActionType type, String name, Map<String, dynamic> attributes) async {
    // NOOP
  }

  @override
  Future<void> startView(
      String key, String name, Map<String, dynamic> attributes) async {
    _jsStartView(name);
  }

  @override
  Future<void> stopResource(String key, int? statusCode, RumResourceType kind,
      int? size, Map<String, dynamic> attributes) async {
    // NOOP
  }

  @override
  Future<void> stopResourceWithError(
      String key, Exception error, Map<String, dynamic> attributes) async {
    // NOOP
  }

  @override
  Future<void> stopResourceWithErrorInfo(String key, String message,
      String type, Map<String, dynamic> attributes) async {
    // NOOP
  }

  @override
  Future<void> stopAction(
      RumActionType type, String name, Map<String, dynamic> attributes) async {
    // NOOP
  }

  @override
  Future<void> stopView(String key, Map<String, dynamic> attributes) async {
    // NOOP
  }

  @override
  Future<void> addFeatureFlagEvaluation(String name, Object value) async {
    _jsAddFeatureFlagEvaluation(name, value);
  }

  @override
  Future<void> stopSession() async {
    _jsStopSession();
  }

  @override
  Future<void> reportLongTask(DateTime at, int durationMs) async {
    // NOOP - The browser SDK will report this automatically
  }

  @override
  Future<void> updatePerformanceMetrics(
      List<double> buildTimes, List<double> rasterTimes) async {
    // NOOP - Not supported by the Browser SDK
  }
}

@JS()
@anonymous
class _RumInitOptions {
  external String get applicationId;
  external String get clientToken;
  external String get site;
  external String? get service;
  external String? get env;
  external String? get version;
  external bool? get trackViewsManually;
  external bool? get trackUserInteractions;
  external bool? get trackFrustrations;
  external bool? get trackLongTasks;
  external String? get defaultPrivacyLevel;
  external num? get sampleRate;
  external num? get sessionReplaySampleRate;
  external bool? get silentMultipleInit;
  external String? get proxyUrl;
  external List<String> get allowedTracingOrigins;
  external List<String> get enableExperimentalFeatures;

  external factory _RumInitOptions({
    String applicationId,
    String clientToken,
    String site,
    String? service,
    String? env,
    String? version,
    bool? trackViewsManually,
    bool? trackUserInteractions,
    bool? trackFrustrations,
    bool? trackLongTasks,
    String? defaultPrivacyLevel,
    num? sampleRate,
    num? sessionReplaySampleRate,
    bool? silentMultipleInit,
    String? proxyUrl,
    List<String> allowedTracingOrigins,
    List<String> enableExperimentalFeatures,
  });
}

@JS()
external void init(_RumInitOptions configuration);

@JS('startView')
external void _jsStartView(String name);

@JS('setRumGlobalContext')
external void _jsSetRumGlobalContext(dynamic context);

@JS('addTiming')
external void _jsAddTiming(String name);

@JS('addError')
external void _jsAddError(dynamic error, dynamic context);

@JS('addAction')
external void _jsAddAction(String action, dynamic context);

@JS('addFeatureFlagEvaluation')
external void _jsAddFeatureFlagEvaluation(String name, dynamic value);

@JS('stopSession')
external void _jsStopSession();
