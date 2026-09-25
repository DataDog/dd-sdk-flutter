// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openfeature_client_provider_contract/client_provider_contract.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

/// Controls only HTTP responses. All lifecycle and evaluation code is Datadog's.
final class DatadogProviderFixture implements ClientProviderFixture {
  final _flags = <String?, Map<String, Object>>{};
  final _gates = <_HeldResponse>[];
  _HeldResponse? _nextGate;
  bool _failNext = false;
  late final http.Client _transport = MockClient(_respond);
  late final datadog = DatadogOpenFeatureProvider(
    configuration: DatadogFlagsConfiguration(
      datadogConfig: const DatadogFlagsConfig(
        clientToken: 'contract-test-token',
        env: 'test',
        site: DatadogFlagsSite.us1,
      ),
      httpClient: _transport,
      initializationTimeout: const Duration(seconds: 1),
      trackExposures: false,
      trackEvaluations: false,
    ),
  );
  late final _counted = _CountingProvider(datadog);

  @override
  FeatureProvider get provider => _counted;
  @override
  int get shutdownCalls => _counted.shutdownCalls;
  @override
  bool get supportsReinitialization => true;
  @override
  void setFlags(String? subject, Map<String, Object> flags) {
    _flags[subject] = Map.of(flags);
  }

  @override
  Future<void> refresh() => datadog.refresh();
  @override
  void failNextRequest() => _failNext = true;
  @override
  HeldProviderResponse holdNextResponse() {
    final held = _HeldResponse();
    _gates.add(held);
    _nextGate = held;
    return held;
  }

  Future<http.Response> _respond(http.Request request) async {
    if (request.url.path != '/precompute-assignments') {
      return http.Response('{}', 202);
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final subject =
        body['data']['attributes']['subject']['targeting_key'] as String?;
    final fail = _failNext;
    _failNext = false;
    // Capture bytes before waiting so old responses cannot read new state.
    final response = jsonEncode({
      'data': {
        'attributes': {
          'flags': {
            for (final entry in (_flags[subject] ?? {}).entries)
              entry.key: {
                'allocationKey': 'contract-allocation',
                'variationKey': 'contract-variant',
                'variationType': switch (entry.value) {
                  bool() => 'boolean',
                  int() => 'integer',
                  double() => 'float',
                  String() => 'string',
                  _ => 'object',
                },
                'variationValue': entry.value,
                'reason': 'TARGETING_MATCH',
                'doLog': false,
              },
          },
        },
      },
    });
    final held = _nextGate;
    _nextGate = null;
    if (held != null) {
      held._started.complete();
      await held._released.future;
    }
    return fail
        ? http.Response('unavailable', 503)
        : http.Response(response, 200);
  }

  @override
  Future<void> close() async {
    for (final gate in _gates) {
      gate.release();
    }
    await datadog.shutdown();
    _transport.close();
  }
}

final class _HeldResponse implements HeldProviderResponse {
  final _started = Completer<void>();
  final _released = Completer<void>();
  @override
  Future<void> get started => _started.future;
  @override
  void release() {
    if (!_released.isCompleted) _released.complete();
  }
}

/// Observes SDK shutdown calls and delegates every operation without changes.
final class _CountingProvider
    implements
        FeatureProvider,
        InitializableProvider,
        ContextReconciliationProvider,
        ShutdownProvider,
        ProviderEventSource,
        DomainScopedProvider {
  final DatadogOpenFeatureProvider delegate;
  int shutdownCalls = 0;
  _CountingProvider(this.delegate);
  @override
  ProviderMetadata get metadata => delegate.metadata;
  @override
  Stream<ProviderEvent> get events => delegate.events;
  @override
  Future<void> initialize(EvaluationContext context, {String? domain}) =>
      delegate.initialize(context, domain: domain);
  @override
  Future<void> onContextChanged(
    EvaluationContext previousContext,
    EvaluationContext newContext,
  ) => delegate.onContextChanged(previousContext, newContext);
  @override
  Future<void> shutdown() {
    shutdownCalls++;
    return delegate.shutdown();
  }

  @override
  ResolutionDetails<bool> resolveBooleanValue(
    String key,
    bool fallback,
    EvaluationContext context,
  ) => delegate.resolveBooleanValue(key, fallback, context);
  @override
  ResolutionDetails<String> resolveStringValue(
    String key,
    String fallback,
    EvaluationContext context,
  ) => delegate.resolveStringValue(key, fallback, context);
  @override
  ResolutionDetails<int> resolveIntegerValue(
    String key,
    int fallback,
    EvaluationContext context,
  ) => delegate.resolveIntegerValue(key, fallback, context);
  @override
  ResolutionDetails<double> resolveDoubleValue(
    String key,
    double fallback,
    EvaluationContext context,
  ) => delegate.resolveDoubleValue(key, fallback, context);
  @override
  ResolutionDetails<Map<String, Object?>> resolveStructureValue(
    String key,
    Map<String, Object?> fallback,
    EvaluationContext context,
  ) => delegate.resolveStructureValue(key, fallback, context);
}
