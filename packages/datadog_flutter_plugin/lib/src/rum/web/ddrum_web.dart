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
import 'rum_web_plugin.dart';

class DdRumWeb extends DdRumPlatform {
  final Uuid _uuid = Uuid();
  RumWebPluginImpl? _webPlugin;
  final Map<String, _ResourceStartInfo> _startedResources = {};

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

    DD_RUM?.init(
      _RumInitOptions(
        applicationId: rumConfiguration.applicationId,
        propagateTraceBaggage: true,
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
        trackSessionAcrossSubdomains:
            configuration.trackSessionsAcrossSubdomains,
        traceContextInjection: _contextInjectionString(
          rumConfiguration.traceContextInjection,
        ),
        trackViewsManually: true,
        trackUserInteractions: false,
        trackResources: trackResources,
        trackResourceHeaders: _convertTrackResourceHeaders(
          rumConfiguration.trackResourceHeaders,
        ),
        trackFrustrations: rumConfiguration.trackFrustrations,
        trackLongTasks: rumConfiguration.detectLongTasks,
        enableExperimentalFeatures: [
          'feature_flags'.toJS,
          'feature_operation_vital'.toJS,
          'start_stop_action'.toJS,
          'start_stop_resource'.toJS,
          // Required to emit resource headers on Browser SDK v6.x (GA in v7.1.0+).
          if (rumConfiguration.trackResourceHeaders != null)
            'track_resource_headers'.toJS,
        ].toJS,
        trackingConsent: trackingConsent.webValue(),
        compressIntakeRequests: false,
        plugins: plugins,
        variant: configuration.flavor,
        source: 'flutter',
        sessionPersistence:
            configuration.sessionPersistence?.webValue() ?? 'cookie',
        sdkVersion: DatadogSdk.sdkVersion,
        usePartitionedCrossSiteSessionCookie:
            configuration.usePartitionedCrossSiteSessionCookie,
        useSecureSessionCookie: configuration.useSecureSessionCookie,
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
  Future<void> addViewAttribute(String key, Object value) async {
    DD_RUM?.setViewContextProperty(key, valueToJs(value, 'value'));
  }

  @override
  Future<void> removeViewAttribute(String key) async {
    DD_RUM?.removeViewContextProperty(key);
  }

  @override
  Future<void> addViewAttributes(Map<String, Object?> attributes) async {
    for (final attr in attributes.entries) {
      DD_RUM?.setViewContextProperty(
          attr.key, valueToJs(attr.value, 'attribute[${attr.key}]'));
    }
  }

  @override
  Future<void> removeViewAttributes(List<String> keys) async {
    for (final key in keys) {
      DD_RUM?.removeViewContextProperty(key);
    }
  }

  @override
  Future<void> startResource(
    DateTime timestamp,
    String key,
    RumHttpMethod httpMethod,
    String url,
    Map<String, dynamic> attributes,
  ) async {
    final method = httpMethod.name.toUpperCase();
    _startedResources[key] = _ResourceStartInfo(url, method);
    final context = attributesToJs(attributes, 'attributes');
    DD_RUM?.startResource(
      url,
      _ResourceStartOptions(
        type: 'other',
        method: method,
        context: context,
        resourceKey: key,
      ),
    );
  }

  @override
  Future<void> startAction(
    DateTime timestamp,
    RumActionType type,
    String name,
    Map<String, dynamic> attributes,
  ) async {
    final context = attributesToJs(attributes, 'attributes');
    DD_RUM?.startAction(
      name,
      _ActionOptions(
        type: actionTypeToJs(type),
        context: context,
      ),
    );
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
    _startedResources.remove(key);
    final context = attributesToJs(attributes, 'attributes');
    DD_RUM?.stopResource(
      key,
      _ResourceStopOptions(
        statusCode: statusCode,
        type: kind.webValue(),
        size: size,
        context: context,
        resourceKey: key,
      ),
    );
  }

  @override
  Future<void> stopResourceWithError(
    DateTime timestamp,
    String key,
    Exception error,
    Map<String, dynamic> attributes,
  ) async {
    await stopResourceWithErrorInfo(
      timestamp,
      key,
      error.toString(),
      error.runtimeType.toString(),
      attributes,
    );
  }

  @override
  Future<void> stopResourceWithErrorInfo(
    DateTime timestamp,
    String key,
    String message,
    String type,
    Map<String, dynamic> attributes,
  ) async {
    final startInfo = _startedResources.remove(key);
    if (startInfo == null) return;

    final context = attributesToJs(attributes, 'attributes');

    DD_RUM?.stopResource(
      key,
      _ResourceStopOptions(
        context: context,
        resourceKey: key,
      ),
    );

    final epochTime = timestamp.millisecondsSinceEpoch;
    final eventTime = _toRelativeTime(timestamp);
    final id = _uuid.v4();
    _webPlugin?.addEvent(
      eventTime,
      RumWebRawErrorEvent(
        date: epochTime.toJS,
        context: context,
        error: RumWebRawErrorData(
          id: id.toString(),
          message: message,
          source: 'network',
          type: type,
          resource: RumWebRawErrorResource(
            method: startInfo.method,
            status_code: 0,
            url: startInfo.url,
          ),
        ),
      ),
      RumWebErrorEventDomainContext(),
    );
  }

  @override
  Future<void> stopAction(
    DateTime timestamp,
    RumActionType type,
    String name,
    Map<String, dynamic> attributes,
  ) async {
    final context = attributesToJs(attributes, 'attributes');
    DD_RUM?.stopAction(
      name,
      _ActionOptions(
        type: actionTypeToJs(type),
        context: context,
      ),
    );
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
  Future<void> startFeatureOperation(DateTime timestamp, String name,
      String? operationKey, Map<String, Object?> attributes) async {
    final context = attributesToJs(attributes, 'attributes');
    DD_RUM?.startFeatureOperation(
      name,
      _FeatureOperationOptions(
        operationKey: operationKey,
        context: context,
      ),
    );
  }

  @override
  Future<void> succeedFeatureOperation(DateTime timestamp, String name,
      String? operationKey, Map<String, Object?> attributes) async {
    final context = attributesToJs(attributes, 'attributes');
    DD_RUM?.succeedFeatureOperation(
      name,
      _FeatureOperationOptions(
        operationKey: operationKey,
        context: context,
      ),
    );
  }

  @override
  Future<void> failFeatureOperation(
      DateTime timestamp,
      String name,
      String? operationKey,
      RumFeatureOperationFailureReason failureReason,
      Map<String, Object?> attributes) async {
    final context = attributesToJs(attributes, 'attributes');
    DD_RUM?.failFeatureOperation(
      name,
      failureReason.webValue(),
      _FeatureOperationOptions(
        operationKey: operationKey,
        context: context,
      ),
    );
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

class _ResourceStartInfo {
  final String url;
  final String method;
  _ResourceStartInfo(this.url, this.method);
}

extension RumResourceTypeWebValue on RumResourceType {
  String webValue() {
    switch (this) {
      case RumResourceType.document:
        return 'document';
      case RumResourceType.image:
        return 'image';
      case RumResourceType.xhr:
        return 'xhr';
      case RumResourceType.beacon:
        return 'beacon';
      case RumResourceType.css:
        return 'css';
      case RumResourceType.fetch:
        return 'fetch';
      case RumResourceType.font:
        return 'font';
      case RumResourceType.js:
        return 'js';
      case RumResourceType.media:
        return 'media';
      case RumResourceType.native:
      case RumResourceType.other:
        return 'other';
    }
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

JSAny? _convertTrackResourceHeaders(ResourceHeadersExtractor? extractor) {
  if (extractor == null) return null;

  // Explicit per-direction MatchHeaders — Browser SDK's `true` mode would
  // apply its broad default list to both directions.
  final matchers = <_MatchHeader>[
    for (final name in extractor.requestHeaderNames)
      _MatchHeader(name: name, location: 'request'),
    for (final name in extractor.responseHeaderNames)
      _MatchHeader(name: name, location: 'response'),
  ];
  if (matchers.isEmpty) return null;
  return matchers.toJS;
}

String _contextInjectionString(TraceContextInjection contextInjection) {
  switch (contextInjection) {
    case TraceContextInjection.all:
      return 'all';
    case TraceContextInjection.sampled:
      return 'sampled';
  }
}

extension on RumFeatureOperationFailureReason {
  String webValue() {
    switch (this) {
      case RumFeatureOperationFailureReason.error:
        return 'error';
      case RumFeatureOperationFailureReason.abandoned:
        return 'abandoned';
      case RumFeatureOperationFailureReason.other:
        return 'other';
    }
  }
}

@anonymous
extension type _MatchHeader._(JSObject _) implements JSObject {
  external factory _MatchHeader({String name, String? location});
}

@anonymous
extension type _TracingUrl._(JSObject _) implements JSObject {
  external JSRegExp match;
  external JSArray propagatorTypes;

  external factory _TracingUrl({JSFunction match, JSArray propagatorTypes});
}

@anonymous
extension type _RumInitOptions._(JSObject _) implements JSObject {
  external factory _RumInitOptions({
    JSArray allowedTracingUrls,
    String applicationId,
    String clientToken,
    bool compressIntakeRequests,
    // ignore: unused_element_parameter
    String? defaultPrivacyLevel,
    JSArray enableExperimentalFeatures,
    String? env,
    JSArray? plugins,
    bool? propagateTraceBaggage,
    String? proxy,
    String? sdkVersion,
    String? service,
    String? sessionPersistence,
    num? sessionSampleRate,
    num? sessionReplaySampleRate,
    String site,
    String? source,
    String? traceContextInjection,
    num? traceSampleRate,
    bool? trackSessionAcrossSubdomains,
    bool? trackFrustrations,
    String? trackingConsent,
    bool? trackResources,
    JSAny? trackResourceHeaders,
    // ignore: unused_element_parameter
    bool? trackUserInteractions,
    bool? trackViewsManually,
    bool? trackLongTasks,
    bool? usePartitionedCrossSiteSessionCookie,
    bool? useSecureSessionCookie,
    String? version,
    String? variant,
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

extension type _FeatureOperationOptions._(JSObject _) implements JSObject {
  external factory _FeatureOperationOptions({
    String? operationKey,
    JSObject? context,
    // ignore: unused_element_parameter
    String? description,
  });
}

@anonymous
extension type _ActionOptions._(JSObject _) implements JSObject {
  external factory _ActionOptions({
    String? type,
    JSObject? context,
    // ignore: unused_element_parameter
    String? actionKey,
  });
}

@anonymous
extension type _ResourceStartOptions._(JSObject _) implements JSObject {
  external factory _ResourceStartOptions({
    String? type,
    String? method,
    JSObject? context,
    String? resourceKey,
  });
}

@anonymous
extension type _ResourceStopOptions._(JSObject _) implements JSObject {
  external factory _ResourceStopOptions({
    int? statusCode,
    String? type,
    int? size,
    JSObject? context,
    String? resourceKey,
  });
}

extension type _DdRum._(JSObject _) implements JSObject {
  external void init(_RumInitOptions configuration);
  external _RumInternalContext? getInternalContext();
  external void startView(String name);
  external void setGlobalContextProperty(String property, JSAny? context);
  external void removeGlobalContextProperty(String property);
  external void setViewContextProperty(String property, JSAny? context);
  external void removeViewContextProperty(String property);
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
  external void startFeatureOperation(
      String name, _FeatureOperationOptions options);
  external void succeedFeatureOperation(
      String name, _FeatureOperationOptions options);
  external void failFeatureOperation(
      String name, String failureReason, _FeatureOperationOptions options);
  external void startAction(String name, _ActionOptions? options);
  external void stopAction(String name, _ActionOptions? options);
  external void startResource(String url, _ResourceStartOptions? options);
  external void stopResource(String url, _ResourceStopOptions? options);
}

@JS()
// ignore: non_constant_identifier_names
external _DdRum? DD_RUM;
