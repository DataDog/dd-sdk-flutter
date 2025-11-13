// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.
// ignore_for_file: unused_element, library_private_types_in_public_api

import 'dart:js_interop';

import 'package:uuid/uuid.dart';

import '../../../datadog_flutter_plugin.dart';
import '../../../datadog_flutter_plugin_web.dart';
import '../../../datadog_internal.dart';
import '../../web_helpers.dart';
import '../ddrum_platform_interface.dart';
import 'raw_events.dart';
import 'resource_tracker.dart';
import 'rum_web_plugin.dart';

class DdRumWeb extends DdRumPlatform {
  final Uuid _uuid = Uuid();
  RumWebPluginImpl? _webPlugin;
  ResourceTracker? _resourceTracker;

  @override
  // Can return this directly, don't need to use a cached version
  String? get cachedSessionId => DD_RUM?.getInternalContext()?.session_id;

  // Because Web needs the full SDK configuration, we have a separate init method
  void initialize(
    DatadogConfiguration configuration,
    DatadogRumConfiguration rumConfiguration,
    InternalLogger logger,
    TrackingConsent trackingConsent,
  ) {
    bool trackResources =
        configuration.additionalConfig[trackResourcesConfigKey] == true;

    final sanitizedFirstPartyHosts = FirstPartyHost.createSanitized(
      configuration.firstPartyHostsWithTracingHeaders,
      logger,
    );

    _webPlugin = RumWebPluginImpl();
    final plugins = [
      createJSInteropWrapper<RumWebPluginImpl>(_webPlugin!),
    ].toJS;

    _resourceTracker = ResourceTracker(_webPlugin!);

    DD_RUM?.init(
      _RumInitOptions(
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
              match: ((String check) {
                final uri = Uri.parse(check);
                return host.regExp.hasMatch(uri.host);
              }).toJS,
              propagatorTypes: host.headerTypes
                  .map(_headerTypeToPropagatorType)
                  .toList()
                  .toJS,
            ),
        ].toJS,
        traceSampleRate: rumConfiguration.traceSampleRate,
        traceContextInjection: _contextInjectionString(
          rumConfiguration.traceContextInjection,
        ),
        trackViewsManually: true,
        trackUserInteractions: false,
        trackResources: trackResources,
        trackFrustrations: rumConfiguration.trackFrustrations,
        trackLongTasks: rumConfiguration.detectLongTasks,
        enableExperimentalFeatures: ['feature_flags'.toJS].toJS,
        trackingConsent: trackingConsent.webValue(),
        // TODO(RUM-11211): Support and document web configuration options.
        compressIntakeRequests: false,
        plugins: plugins,
        variant: configuration.flavor,
        source: 'flutter',
        sdkVersion: DatadogSdk.sdkVersion,
      ),
    );
  }

  @override
  Future<void> enable(
    DatadogSdk core,
    DatadogRumConfiguration configuration,
  ) async {}

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
  Future<void> setInternalViewAttribute(String key, Object value) async {
    // NOOP - Not supported by the Browser SDK
  }

  @override
  Future<void> addError(
    DateTime timestamp,
    Object error,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, dynamic> attributes,
  ) async {
    final epochTime = timestamp.millisecondsSinceEpoch;
    final eventTime = _toRelativeTime(timestamp);

    final fingerprint = attributes.remove(DatadogAttributes.errorFingerprint);

    final id = _uuid.v4();
    final context = attributesToJs(attributes, 'attributes');
    _webPlugin?.addEvent(
      eventTime,
      RumWebRawErrorEvent(
        date: epochTime.toJS,
        context: context,
        error: RumWebRawErrorData(
          id: id.toString(),
          message: error.toString(),
          source: errorSourceToJs(source),
          stack: convertWebStackTrace(stackTrace),
          type: errorType ?? 'UnknownError',
          fingerprint: fingerprint,
        ),
      ),
      RumWebErrorEventDomainContext(),
    );
  }

  @override
  Future<void> addErrorInfo(
    DateTime timestamp,
    String message,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, dynamic> attributes,
  ) async {
    final epochTime = timestamp.millisecondsSinceEpoch;
    final eventTime = _toRelativeTime(timestamp);

    final fingerprint = attributes.remove(DatadogAttributes.errorFingerprint);

    final id = _uuid.v4();
    final context = attributesToJs(attributes, 'attributes');

    _webPlugin?.addEvent(
      eventTime,
      RumWebRawErrorEvent(
        date: epochTime.toJS,
        context: context,
        error: RumWebRawErrorData(
          id: id.toString(),
          message: message,
          source: errorSourceToJs(source),
          stack: convertWebStackTrace(stackTrace),
          type: errorType ?? 'UnknownError',
          fingerprint: fingerprint,
        ),
      ),
      RumWebErrorEventDomainContext(),
    );
  }

  @override
  Future<void> addTiming(DateTime timestamp, String name) async {
    DD_RUM?.addTiming(name);
  }

  @override
  Future<void> addViewLoadingTime(bool overwrite) async {
    // NOOP - Not supported by the Browser SDK
  }

  @override
  Future<void> addAction(
    DateTime timestamp,
    RumActionType type,
    String name,
    Map<String, dynamic> attributes,
  ) async {
    final epochTime = timestamp.millisecondsSinceEpoch;
    final eventTime = _toRelativeTime(timestamp);

    final id = _uuid.v4();
    final context = attributesToJs(attributes, 'attributes');

    // TODO(RUM-): Replace with plugin bridge call.
    _webPlugin?.addEvent(
      eventTime,
      RumWebRawActionEvent(
        date: epochTime.toJS,
        context: context,
        action: RumWebRawActionData(
          id: id.toString(),
          type: actionTypeToJs(type),
          target: RumWebActionTarget(name: name),
        ),
      ),
      RumWebActionEventDomainContext(),
    );
  }

  @override
  Future<void> removeAttribute(String key) async {
    DD_RUM?.removeGlobalContextProperty(key);
  }

  @override
  Future<void> startResource(
    DateTime timestamp,
    String key,
    RumHttpMethod httpMethod,
    String url,
    Map<String, dynamic> attributes,
  ) async {
    _resourceTracker?.startResource(
      timestamp,
      key,
      httpMethod,
      url,
      attributes,
    );
  }

  @override
  Future<void> startAction(
    DateTime timestamp,
    RumActionType type,
    String name,
    Map<String, dynamic> attributes,
  ) async {
    // NOOP
  }

  @override
  Future<void> startView(
    DateTime timestamp,
    String key,
    String name,
    Map<String, dynamic> attributes,
  ) async {
    DD_RUM?.startView(name);
  }

  @override
  Future<void> stopResource(
    DateTime timestamp,
    String key,
    int? statusCode,
    RumResourceType kind,
    int? size,
    Map<String, dynamic> attributes,
  ) async {
    _resourceTracker?.stopResource(
      timestamp,
      key,
      statusCode,
      kind,
      size,
      attributes,
    );
  }

  @override
  Future<void> stopResourceWithError(
    DateTime timestamp,
    String key,
    Exception error,
    Map<String, dynamic> attributes,
  ) async {
    _resourceTracker?.stopResourceWithError(timestamp, key, error, attributes);
  }

  @override
  Future<void> stopResourceWithErrorInfo(
    DateTime timestamp,
    String key,
    String message,
    String type,
    Map<String, dynamic> attributes,
  ) async {
    _resourceTracker?.stopResourceWithErrorInfo(
      timestamp,
      key,
      message,
      type,
      attributes,
    );
  }

  @override
  Future<void> stopAction(
    DateTime timestamp,
    RumActionType type,
    String name,
    Map<String, dynamic> attributes,
  ) async {
    // NOOP
  }

  @override
  Future<void> stopView(
    DateTime timestamp,
    String key,
    Map<String, dynamic> attributes,
  ) async {
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
    List<double> buildTimes,
    List<double> rasterTimes,
  ) async {
    // NOOP - Not supported by the Browser SDK
  }

  JSNumber _toRelativeTime(DateTime time) {
    return _webPlugin?.getEventRelativeTime(time) ??
        time.microsecondsSinceEpoch.toJS;
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

String _contextInjectionString(TraceContextInjection contextInjection) {
  switch (contextInjection) {
    case TraceContextInjection.all:
      return 'all';
    case TraceContextInjection.sampled:
      return 'sampled';
  }
}

@anonymous
extension type _TracingUrl._(JSObject _) implements JSObject {
  external JSRegExp match;
  external JSArray propagatorTypes;

  external factory _TracingUrl({JSFunction match, JSArray propagatorTypes});
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
  external bool get compressIntakeRequests;
  external JSArray? get plugins;
  external String? get source;
  external String? get sdkVersion;
  external String? get variant;
  external String? get trackingConsent;

  external factory _RumInitOptions({
    String applicationId,
    String clientToken,
    String site,
    String? service,
    String? env,
    String? version,
    bool? trackResources,
    bool? trackViewsManually,
    // ignore: unused_element_parameter
    bool? trackUserInteractions,
    bool? trackFrustrations,
    bool? trackLongTasks,
    // ignore: unused_element_parameter
    String? defaultPrivacyLevel,
    num? sessionSampleRate,
    num? sessionReplaySampleRate,
    // ignore: unused_element_parameter
    bool? silentMultipleInit,
    String? proxy,
    JSArray allowedTracingUrls,
    num? traceSampleRate,
    String? traceContextInjection,
    JSArray enableExperimentalFeatures,
    bool compressIntakeRequests,
    JSArray? plugins,
    String? source,
    String? sdkVersion,
    String? variant,
    String? trackingConsent,
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
  external void setUserProperty(String key, JSAny? value);
  external void clearUser();
  external void setAccount(JsAccount userInfo);
  external void setAccountProperty(String key, JSAny? value);
  external void clearAccount();
  external void setTrackingConsent(String consent);
}

@JS()
// ignore: non_constant_identifier_names
external _DdRum? DD_RUM;
