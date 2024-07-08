// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.
// ignore_for_file: unused_element, library_private_types_in_public_api

import 'dart:js_interop';

import 'package:meta/meta.dart';

import '../../datadog_flutter_plugin.dart';
import '../../datadog_internal.dart';
import '../logs/ddweb_helpers.dart';
import '../web_helpers.dart';
import 'ddrum_platform_interface.dart';

class DdRumWeb extends DdRumPlatform {
  // Because Web needs the full SDK configuration, we have a separate init method
  void initialize(DatadogConfiguration configuration,
      DatadogRumConfiguration rumConfiguration, InternalLogger logger) {
    bool trackResources =
        configuration.additionalConfig[trackResourcesConfigKey] == true;

    final sanitizedFirstPartyHosts = FirstPartyHost.createSanitized(
        configuration.firstPartyHostsWithTracingHeaders, logger);

    DD_RUM?.init(_RumInitOptions(
      applicationId: rumConfiguration.applicationId,
      clientToken: configuration.clientToken,
      site: siteStringForSite(configuration.site),
      sessionSampleRate: rumConfiguration.sessionSamplingRate,
      sessionReplaySampleRate: 0,
      service: configuration.service,
      env: configuration.env,
      version: configuration.versionTag,
      proxy: rumConfiguration.customEndpoint,
      allowedTracingUrls: [
        for (final host in sanitizedFirstPartyHosts)
          _TracingUrl(
            match: host.regExp.toJs(),
            propagatorTypes:
                host.headerTypes.map(_headerTypeToPropagatorType).toList().toJS,
          )
      ].toJS,
      trackViewsManually: true,
      trackResources: trackResources,
      trackFrustrations: rumConfiguration.trackFrustrations,
      trackLongTasks: rumConfiguration.detectLongTasks,
      enableExperimentalFeatures: ['feature_flags'.toJS].toJS,
    ));
  }

  @override
  Future<void> enable(
      DatadogSdk core, DatadogRumConfiguration configuration) async {}

  @override
  Future<void> deinitialize() async {}

  @override
  Future<String?> getCurrentSessionId() async {
    return DD_RUM?.getInternalContext()?.session_id;
  }

  @override
  Future<void> addAttribute(String key, dynamic value) async {
    DD_RUM?.setGlobalContextProperty(key, valueToJs(value, 'context'));
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

    final fingerprint = attributes.remove(DatadogAttributes.errorFingerprint);
    if (fingerprint != null) {
      jsError.dd_fingerprint = fingerprint;
    }

    DD_RUM?.addError(jsError, attributesToJs(attributes, 'attributes'));
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

    final fingerprint = attributes.remove(DatadogAttributes.errorFingerprint);
    if (fingerprint != null) {
      jsError.dd_fingerprint = fingerprint;
    }

    DD_RUM?.addError(jsError, attributesToJs(attributes, 'attributes'));
  }

  @override
  Future<void> addTiming(String name) async {
    DD_RUM?.addTiming(name);
  }

  @override
  Future<void> addAction(
      RumActionType type, String name, Map<String, dynamic> attributes) async {
    DD_RUM?.addAction(name, attributesToJs(attributes, 'attributes'));
  }

  @override
  Future<void> removeAttribute(String key) async {
    DD_RUM?.removeGlobalContextProperty(key);
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
    DD_RUM?.startView(name);
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
  Future<void> addFeatureFlagEvaluation(String name, Object? value) async {
    DD_RUM?.addFeatureFlagEvaluation(name, valueToJs(value, 'value'));
  }

  @override
  Future<void> stopSession() async {
    DD_RUM?.stopSession();
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

JSString _headerTypeToPropagatorType(TracingHeaderType type) {
  switch (type) {
    case TracingHeaderType.datadog:
      return 'datadog'.toJS;
    case TracingHeaderType.b3:
      return 'b3'.toJS;
    case TracingHeaderType.b3multi:
      return 'b3multi'.toJS;
    case TracingHeaderType.tracecontext:
      return 'tracecontext'.toJS;
  }
}

@anonymous
extension type _TracingUrl._(JSObject _) implements JSObject {
  external JSRegExp match;
  external JSArray propagatorTypes;

  external factory _TracingUrl({
    JSRegExp match,
    JSArray propagatorTypes,
  });
}

@anonymous
extension type _RumInitOptions._(JSObject _) implements JSObject {
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
  external num? get sessionSampleRate;
  external num? get sessionReplaySampleRate;
  external bool? get silentMultipleInit;
  external String? get proxy;
  external JSArray get allowedTracingUrls;
  external JSArray get enableExperimentalFeatures;

  external factory _RumInitOptions({
    String applicationId,
    String clientToken,
    String site,
    String? service,
    String? env,
    String? version,
    bool? trackResources,
    bool? trackViewsManually,
    bool? trackUserInteractions,
    bool? trackFrustrations,
    bool? trackLongTasks,
    String? defaultPrivacyLevel,
    num? sessionSampleRate,
    num? sessionReplaySampleRate,
    bool? silentMultipleInit,
    String? proxy,
    JSArray allowedTracingUrls,
    JSArray enableExperimentalFeatures,
  });
}

extension ToJs on RegExp {
  JSRegExp toJs() {
    return JSRegExp(pattern);
  }
}

extension type _RumInternalContext._(JSObject _) implements JSObject {
  // ignore: non_constant_identifier_names
  external String? application_id;
  // ignore: non_constant_identifier_names
  external String? session_id;
}

@anonymous
@internal
extension type JsUser._(JSObject _) implements JSObject {
  external String? get id;
  external String? get email;
  external String? get name;

  external factory JsUser({
    String? id,
    String? email,
    String? name,
  });
}

extension type _DdRum._(JSObject _) implements JSObject {
  external void init(_RumInitOptions configuration);
  external _RumInternalContext? getInternalContext();
  external void startView(String name);
  external void setGlobalContextProperty(String property, JSAny? context);
  external void removeGlobalContextProperty(String property);
  external void addTiming(String name);
  external void addError(JSObject error, JSAny? context);
  external void addAction(String action, JSAny? context);
  external void addFeatureFlagEvaluation(String name, JSAny? value);
  external void stopSession();
  external void setUser(JsUser newUser);
}

@JS()
// ignore: non_constant_identifier_names
external _DdRum? DD_RUM;
