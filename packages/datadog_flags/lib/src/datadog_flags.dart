// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:http/http.dart' as http;

import 'default_flags_client.dart';
import 'evaluation_aggregator.dart';
import 'exposure_logger.dart';
import 'flag_assignments_fetcher.dart';
import 'flags_client.dart';
import 'flags_configuration.dart';
import 'flags_repository.dart';
import 'flags_runtime.dart';
import 'no_op_flags_client.dart';

/// Entry point for configuring and creating Datadog feature flag clients.
///
/// `DatadogFlags` state is local to the current Dart isolate. Background
/// isolates must use their own [DatadogFlags] instance, create any clients they
/// need, and initialize each client before evaluating flags.
class DatadogFlags {
  /// Name used for the shared client when no explicit client name is provided.
  static const defaultClientName = 'default';

  static DatadogFlags? _singleton;

  /// Process-wide convenience instance for applications that do not need to
  /// inject their own [DatadogFlags] owner.
  static DatadogFlags get instance {
    _singleton ??= DatadogFlags();
    return _singleton!;
  }

  http.Client? _httpClient;
  bool _ownsHttpClient = false;
  DatadogFlagsConfiguration? _configuration;
  final Map<String, DatadogFlagsClient> _clients = {};

  /// Creates an isolated Datadog Flags owner.
  ///
  /// Prefer this constructor in tests or when an application owns multiple
  /// independent SDK lifecycles. Most applications can use [instance].
  DatadogFlags();

  /// Whether [enable] has completed with a usable Datadog configuration.
  bool get isEnabled => _configuration != null;

  /// Enables feature flag clients with the supplied SDK [configuration].
  ///
  /// Calling this method replaces any existing configuration, shuts down
  /// existing clients, and recreates the default shared client. If
  /// [DatadogFlagsConfiguration.datadogConfig] is omitted, clients remain
  /// available but return default values with `providerNotReady` errors.
  Future<void> enable({
    DatadogFlagsConfiguration configuration = const DatadogFlagsConfiguration(),
  }) async {
    await disable();

    final datadogConfig = configuration.datadogConfig;
    if (datadogConfig == null) {
      return;
    }

    final customHttpClient = configuration.httpClient;
    _httpClient = customHttpClient ?? http.Client();
    _ownsHttpClient = customHttpClient == null;
    _configuration = configuration;
    sharedClient();
  }

  /// Returns the named feature flag client, creating it if necessary.
  ///
  /// Use different client names for independent subjects, such as logged-out
  /// device context and logged-in user context.
  DatadogFlagsClient sharedClient({String name = defaultClientName}) {
    return _client(name);
  }

  /// Clears in-memory and stored assignments for all clients.
  Future<void> reset() async {
    await Future.wait(_clients.values.map((client) => client.reset()));
  }

  /// Shuts down all clients and releases SDK-owned resources.
  ///
  /// After disabling, existing clients are discarded and future evaluations use
  /// default values until [enable] is called again.
  Future<void> disable() async {
    await Future.wait(_clients.values.map((client) => client.shutdown()));
    _clients.clear();
    if (_ownsHttpClient) {
      _httpClient?.close();
    }
    _httpClient = null;
    _ownsHttpClient = false;
    _configuration = null;
  }

  DatadogFlagsClient _client(String name) {
    final existing = _clients[name];
    if (existing != null) {
      return existing;
    }

    final configuration = _configuration;
    final datadogConfig = configuration?.datadogConfig;
    final httpClient = _httpClient;
    if (configuration == null || datadogConfig == null || httpClient == null) {
      final client = NoOpDatadogFlagsClient(name: name);
      _clients[name] = client;
      return client;
    }

    final fetcher = FlagAssignmentsFetcher(
      datadogConfig: datadogConfig,
      configuration: configuration,
      httpClient: httpClient,
    );
    final runtime = FlagsRuntime(
      configuration: configuration,
      datadogConfig: datadogConfig,
      httpClient: httpClient,
    );

    final repository = FlagsRepository(
      clientName: name,
      fetcher: fetcher,
      store: configuration.store,
      dateProvider: configuration.dateProvider,
    );

    final client = DefaultDatadogFlagsClient(
      name: name,
      repository: repository,
      exposureLogger: ExposureLogger(runtime),
      evaluationAggregator: EvaluationAggregator(runtime),
    );
    _clients[name] = client;
    return client;
  }
}
