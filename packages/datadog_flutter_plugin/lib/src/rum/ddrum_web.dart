// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.
// ignore_for_file: unused_element

@JS('DD_RUM')
library ddrum_flutter_web;

import 'package:js/js.dart';

import '../../datadog_flutter_plugin.dart';
import '../web_helpers.dart';
import 'ddrum_platform_interface.dart';

class DdRumWeb extends DdRumPlatform {
  final Map<String, dynamic> currentAttributes = {};

  void initRum(DdSdkConfiguration configuration) {
    final rumConfiguration = configuration.rumConfiguration;
    if (rumConfiguration == null) {
      return;
    }

    init(_RumInitOptions(
      applicationId: rumConfiguration.applicationId,
      clientToken: configuration.clientToken,
      site: siteStringForSite(configuration.site),
      sampleRate: rumConfiguration.sampleRate,
      service: configuration.serviceName,
      env: configuration.env,
      proxyUrl: configuration.customEndpoint,
      allowedTracingOrigins: configuration.firstPartyHosts,
      trackViewsManually: true,
    ));
  }

  @override
  Future<void> addAttribute(String key, dynamic value) async {
    currentAttributes[key] = value;
    _jsSetRumGlobalContext(attributesToJs(currentAttributes, 'context'));
  }

  @override
  Future<void> addError(Object error, RumErrorSource source,
      StackTrace? stackTrace, Map<String, dynamic> attributes) async {
    _jsAddError(error.toString(), attributesToJs(attributes, 'attributes'));
  }

  @override
  Future<void> addErrorInfo(String message, RumErrorSource source,
      StackTrace? stackTrace, Map<String, dynamic> attributes) async {
    _jsAddError(message, attributesToJs(attributes, 'attributes'));
  }

  @override
  Future<void> addTiming(String name) async {
    _jsAddTiming(name);
  }

  @override
  Future<void> addUserAction(RumUserActionType type, String name,
      Map<String, dynamic> attributes) async {
    _jsAddAction(name, attributesToJs(attributes, 'attributes'));
  }

  @override
  Future<void> removeAttribute(String key) async {
    currentAttributes.remove(key);
    _jsSetRumGlobalContext(attributesToJs(currentAttributes, 'context'));
  }

  @override
  Future<void> startResourceLoading(String key, RumHttpMethod httpMethod,
      String url, Map<String, dynamic> attributes) async {
    // NOOP
  }

  @override
  Future<void> startUserAction(RumUserActionType type, String name,
      Map<String, dynamic> attributes) async {
    // NOOP
  }

  @override
  Future<void> startView(
      String key, String name, Map<String, dynamic> attributes) async {
    _jsStartView(name);
  }

  @override
  Future<void> stopResourceLoading(String key, int? statusCode,
      RumResourceType kind, int? size, Map<String, dynamic> attributes) async {
    // NOOP
  }

  @override
  Future<void> stopResourceLoadingWithError(
      String key, Exception error, Map<String, dynamic> attributes) async {
    // NOOP
  }

  @override
  Future<void> stopResourceLoadingWithErrorInfo(String key, String message,
      String type, Map<String, dynamic> attributes) async {
    // NOOP
  }

  @override
  Future<void> stopUserAction(RumUserActionType type, String name,
      Map<String, dynamic> attributes) async {
    // NOOP
  }

  @override
  Future<void> stopView(String key, Map<String, dynamic> attributes) async {
    // NOOP
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
  external bool? get trackInteractions;
  external String? get defaultPrivacyLevel;
  external num? get sampleRate;
  external num? get replaySampleRate;
  external bool? get silentMultipleInit;
  external String? get proxyUrl;
  external List<String> get allowedTracingOrigins;

  external factory _RumInitOptions({
    String applicationId,
    String clientToken,
    String site,
    String? service,
    String? env,
    String? version,
    bool? trackViewsManually,
    bool? trackInteractions,
    String? defaultPrivacyLevel,
    num? sampleRate,
    num? replaySampleRate,
    bool? silentMultipleInit,
    String? proxyUrl,
    List<String> allowedTracingOrigins,
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
