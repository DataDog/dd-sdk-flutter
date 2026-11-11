// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/assignment.dart';
import 'package:datadog_flags/src/datadog_openfeature_provider.dart'
    show DatadogOpenFeatureProviderTesting;
import 'package:datadog_flags/src/exposure_hook.dart'
    show exposureHookWithLogger;
import 'package:datadog_flags/src/exposure_logger.dart';
import 'package:datadog_flags/src/flag_assignments_fetcher.dart';
import 'package:datadog_flags/src/flags_log.dart';
import 'package:datadog_flags/src/flags_runtime.dart';
import 'package:datadog_flags/src/intake_platform.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk_experimental.dart'
    show createIsolatedOpenFeatureAPI;
import 'package:test/test.dart';

class _MockLogger extends Mock implements FlagsLogger {}

final class _ThrowingAfterHook extends HookAdapter {
  @override
  void after(
    HookContext context,
    FlagEvaluationDetails<Object> details,
    HookHints hints,
  ) => throw StateError('after hook failed');
}

final class _OtherProvider implements FeatureProvider {
  final String _name;

  _OtherProvider([this._name = 'Other']);

  @override
  ProviderMetadata get metadata => ProviderMetadata(name: _name);

  @override
  ResolutionDetails<bool> resolveBooleanValue(
    String flagKey,
    bool defaultValue,
    EvaluationContext context,
  ) => ResolutionDetails(value: true, variant: 'on');

  @override
  ResolutionDetails<double> resolveDoubleValue(
    String flagKey,
    double defaultValue,
    EvaluationContext context,
  ) => ResolutionDetails(value: defaultValue);

  @override
  ResolutionDetails<int> resolveIntegerValue(
    String flagKey,
    int defaultValue,
    EvaluationContext context,
  ) => ResolutionDetails(value: defaultValue);

  @override
  ResolutionDetails<String> resolveStringValue(
    String flagKey,
    String defaultValue,
    EvaluationContext context,
  ) => ResolutionDetails(value: defaultValue);

  @override
  ResolutionDetails<Map<String, Object?>> resolveStructureValue(
    String flagKey,
    Map<String, Object?> defaultValue,
    EvaluationContext context,
  ) => ResolutionDetails(value: defaultValue);
}

void main() {
  late OpenFeatureAPI api;
  late List<http.Request> requests;
  late Map<String, Object?> flags;
  late List<ExposureEvaluation> evaluations;

  Map<String, Object?> feature(
    String key,
    Object value, [
    List<Object?> destinations = const ['HOOK'],
  ]) => {'key': key, 'value': value, 'destinations': destinations};

  final holdoutFeatures = [
    feature('holdout.key', 'holdout-1'),
    feature('holdout.assignment_group', 'status_quo'),
    feature('holdout.should_include_in_holdout_analysis', false),
    feature('exposure.only', 'e', ['EXPOSURE']),
    feature('evaluation.only', 3, ['EVALUATION']),
    feature('nowhere', 'n', ['FUTURE']),
    feature('holdout.key', 'duplicate', ['HOOK', 'EXPOSURE', 'EVALUATION']),
  ];

  Map<String, Object?> assignment({
    String variationKey = 'on',
    Object variationValue = true,
    String variationType = 'boolean',
    int serialId = 1,
    bool doLog = true,
    List<Object?>? features,
  }) => {
    'allocationKey': 'allocation-a',
    'variationKey': variationKey,
    'variationType': variationType,
    'variationValue': variationValue,
    'reason': 'TARGETING_MATCH',
    'doLog': doLog,
    'serialId': serialId,
    'features': ?features,
  };

  List<Map<String, Object?>> exposureEvents() => [
    for (final request in requests)
      if (request.url.path == '/api/v2/exposures')
        for (final line in request.body.split('\n'))
          if (line.isNotEmpty) jsonDecode(line) as Map<String, Object?>,
  ];

  List<Map<String, Object?>> evaluationEvents() => [
    for (final request in requests)
      if (request.url.path == '/api/v2/flagevaluation')
        for (final event
            in isWebFlagsIntake
                ? LineSplitter.split(request.body).map(jsonDecode)
                : (jsonDecode(request.body)
                          as Map<String, Object?>)['flagEvaluations']!
                      as List<Object?>)
          event! as Map<String, Object?>,
  ];

  const datadogConfig = DatadogFlagsConfig(
    clientToken: 'client-token',
    env: 'test',
    site: DatadogFlagsSite.us1,
  );

  http.Client httpClient() => MockClient((request) async {
    requests.add(request);
    if (request.url.path == '/precompute-assignments') {
      return http.Response(
        jsonEncode({
          'data': {
            'attributes': {'flags': flags},
          },
        }),
        200,
      );
    }
    return http.Response('{}', 202);
  });

  Future<(OpenFeatureClient, DatadogOpenFeatureProvider)> start({
    bool trackExposures = true,
    bool trackEvaluations = true,
    DateTime Function() dateProvider = DateTime.now,
    ExposureHook? hook,
  }) async {
    final provider = DatadogOpenFeatureProvider(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: datadogConfig,
        httpClient: httpClient(),
        trackExposures: trackExposures,
        trackEvaluations: trackEvaluations,
        dateProvider: dateProvider,
      ),
    );
    await api.setEvaluationContextAndWait(
      EvaluationContext(targetingKey: 'user-1', attributes: {'plan': 'pro'}),
    );
    await api.setProviderAndWait(provider);
    api.addHooks([hook ?? ExposureHook(evaluations.add)]);
    return (api.getClient(), provider);
  }

  setUp(() {
    api = createIsolatedOpenFeatureAPI();
    requests = [];
    evaluations = [];
    flags = {
      'flag': assignment(features: holdoutFeatures),
      'plain': assignment(),
      'silent': assignment(doLog: false),
    };
  });

  tearDown(() => api.shutdown());

  test('puts only HOOK features under the public metadata prefix', () async {
    final (client, _) = await start();

    final details = client.getBooleanDetails('flag', false);

    expect(details.value, isTrue);
    expect(
      Map.fromEntries(
        details.flagMetadata.entries.where(
          (entry) => entry.key.contains('feature.'),
        ),
      ),
      {
        '__dd_feature.holdout.key': 'holdout-1',
        '__dd_feature.holdout.assignment_group': 'status_quo',
        '__dd_feature.holdout.should_include_in_holdout_analysis': false,
        '__dd_exposure_feature.exposure.only': 'e',
        '__dd_evaluation_feature.evaluation.only': 3.0,
      },
    );
    expect(evaluations.single.features, {
      'holdout.key': 'holdout-1',
      'holdout.assignment_group': 'status_quo',
      'holdout.should_include_in_holdout_analysis': false,
    });
  });

  test('adds no feature metadata for a split without features', () async {
    final (client, _) = await start();

    final details = client.getBooleanDetails('plain', false);

    expect(details.flagMetadata, {
      'datadog.allocation_key': 'allocation-a',
      'datadog.serial_id': 1,
      '__dd_do_log': true,
      '__dd_split_serial_id': 1,
    });
    expect(evaluations.single.features, isEmpty);
  });

  test('passes the evaluation to the callback', () async {
    final (client, _) = await start();

    client.getBooleanValue('flag', false);

    final evaluation = evaluations.single;
    expect(evaluation.flagKey, 'flag');
    expect(evaluation.variant, 'on');
    expect(evaluation.allocationKey, 'allocation-a');
    expect(evaluation.targetingKey, 'user-1');
    expect(evaluation.evaluationContext.attributes, {'plan': 'pro'});
    expect(evaluation.isExposure, isTrue);
    expect(evaluation.isCacheHit, isFalse);
    expect(evaluation.shouldSend, isTrue);
  });

  test('reports a repeat as a cache hit and sends it once', () async {
    final (client, _) = await start();

    client.getBooleanValue('flag', false);
    client.getBooleanValue('flag', false);
    await api.shutdown();

    expect([for (final e in evaluations) e.isCacheHit], [false, true]);
    expect([for (final e in evaluations) e.shouldSend], [true, false]);
    expect(exposureEvents(), hasLength(1));
  });

  final changes = <String, Map<String, Object?>>{
    'variant': assignment(variationKey: 'off', variationValue: false),
    'serial ID': assignment(serialId: 2),
  };
  for (final MapEntry(key: name, value: changed) in changes.entries) {
    test('reports a $name change as a new exposure', () async {
      final (client, provider) = await start();

      client.getBooleanValue('plain', false);
      flags = {'plain': changed};
      await provider.refresh();
      client.getBooleanValue('plain', false);
      await api.shutdown();

      expect([for (final e in evaluations) e.shouldSend], [true, true]);
      expect(exposureEvents(), hasLength(2));
    });
  }

  test('a change in features only is a cache hit', () async {
    final (client, provider) = await start();

    client.getBooleanValue('flag', false);
    flags = {
      'flag': assignment(
        features: [
          feature('holdout.key', 'holdout-2', ['HOOK', 'EXPOSURE']),
        ],
      ),
    };
    await provider.refresh();
    client.getBooleanValue('flag', false);
    await api.shutdown();

    expect([for (final e in evaluations) e.isCacheHit], [false, true]);
    expect(exposureEvents(), hasLength(1));
  });

  test('closes every exposure frame', () async {
    final (client, provider) = await start();

    client.getBooleanValue('flag', false);
    client.getStringValue('flag', 'default');
    client.getBooleanValue(
      'plain',
      false,
      options: EvaluationOptions(
        hooks: [_ThrowingAfterHook(), _NestedEvaluationHook(client)],
      ),
    );
    provider.resolveBooleanValue('plain', false, EvaluationContext.empty);

    expect(provider.openExposureFrames, 0);
  });

  test('does not report an allocation without exposure logging', () async {
    final (client, _) = await start();

    client.getBooleanValue('silent', false);
    await api.shutdown();

    expect(evaluations.single.isExposure, isFalse);
    expect(evaluations.single.shouldSend, isFalse);
    expect(exposureEvents(), isEmpty);
  });

  test('a type mismatch sends and records nothing', () async {
    final (client, _) = await start();

    expect(client.getStringValue('plain', 'default'), 'default');
    client.getBooleanValue('plain', false);
    await api.shutdown();

    expect([for (final e in evaluations) e.isExposure], [false, true]);
    expect(evaluations.last.isCacheHit, isFalse);
    expect(exposureEvents(), hasLength(1));
  });

  test('a failing after hook sends and records nothing', () async {
    final (client, _) = await start();

    expect(
      client.getBooleanValue(
        'plain',
        false,
        options: EvaluationOptions(hooks: [_ThrowingAfterHook()]),
      ),
      isFalse,
    );
    client.getBooleanValue('plain', false);
    await api.shutdown();

    expect([for (final e in evaluations) e.isExposure], [false, true]);
    expect(evaluations.last.isCacheHit, isFalse);
    expect(exposureEvents(), hasLength(1));
  });

  test('a direct provider call records no exposure', () async {
    final (client, provider) = await start();

    provider.resolveBooleanValue('plain', false, EvaluationContext.empty);
    client.getBooleanValue('plain', false);
    await api.shutdown();

    expect(evaluations.single.shouldSend, isTrue);
    expect(exposureEvents(), hasLength(1));
  });

  test(
    'a direct provider call inside a hook keeps the outer exposure',
    () async {
      final (client, provider) = await start();

      client.getBooleanValue(
        'flag',
        false,
        options: EvaluationOptions(hooks: [_DirectResolveHook(provider)]),
      );
      await api.shutdown();

      expect(evaluations.single.flagKey, 'flag');
      expect(evaluations.single.shouldSend, isTrue);
      expect(
        [for (final event in exposureEvents()) (event['flag']! as Map)['key']],
        ['flag'],
      );
    },
  );

  test('records nested evaluations of the same flag once', () async {
    final (client, _) = await start();
    final nested = _NestedEvaluationHook(client);

    client.getBooleanValue(
      'plain',
      false,
      options: EvaluationOptions(hooks: [nested]),
    );
    await api.shutdown();

    expect([for (final e in evaluations) e.shouldSend], [true, false]);
    expect(exposureEvents(), hasLength(1));
  });

  test(
    'with trackExposures off, sends nothing but keeps the verdicts',
    () async {
      final (client, _) = await start(trackExposures: false);

      client.getBooleanValue('flag', false);
      client.getBooleanValue('flag', false);
      await api.shutdown();

      expect([for (final e in evaluations) e.shouldSend], [true, false]);
      expect([for (final e in evaluations) e.isCacheHit], [false, true]);
      expect(exposureEvents(), isEmpty);
    },
  );

  test('keeps the verdict when recording the exposure throws', () async {
    var throwOnce = false;
    final (client, _) = await start(
      trackEvaluations: false,
      dateProvider: () {
        if (throwOnce) {
          throwOnce = false;
          throw StateError('clock failed');
        }
        return DateTime.now();
      },
    );

    throwOnce = true;
    expect(client.getBooleanValue('plain', false), isTrue);
    client.getBooleanValue('plain', false);

    expect([for (final e in evaluations) e.shouldSend], [true, false]);
    expect([for (final e in evaluations) e.isCacheHit], [false, true]);
  });

  test('a failing callback does not affect the evaluation', () async {
    final logger = _MockLogger();
    final (client, _) = await start(
      hook: exposureHookWithLogger((_) => throw StateError('boom'), logger),
    );

    expect(client.getBooleanValue('flag', false), isTrue);
    final details = client.getBooleanDetails('flag', false);
    await api.shutdown();

    expect(details.value, isTrue);
    expect(details.errorCode, isNull);
    expect(exposureEvents(), hasLength(1));
    verify(() => logger.warning(any(), error: any(named: 'error'))).called(1);
    verify(() => logger.debug(any(), error: any(named: 'error'))).called(1);
  });

  test('a failing logger does not affect the evaluation', () async {
    final logger = _MockLogger();
    when(
      () => logger.warning(any(), error: any(named: 'error')),
    ).thenThrow(StateError('logger failed'));
    final (client, _) = await start(
      hook: exposureHookWithLogger((_) => throw StateError('boom'), logger),
    );

    expect(client.getBooleanDetails('flag', false).errorCode, isNull);
  });

  test('contains a failure of its own logging', () {
    final logger = _MockLogger();
    when(
      () => logger.warning(any(), error: any(named: 'error')),
    ).thenThrow(StateError('logger failed'));
    final hook = exposureHookWithLogger(
      (_) => throw StateError('boom'),
      logger,
    );

    expect(
      () => hook.finallyAfter(
        HookContext(
          flagKey: 'flag',
          defaultValue: false,
          flagValueType: FlagValueType.boolean,
          clientMetadata: const ClientMetadata(),
          providerMetadata: const ProviderMetadata(name: 'Datadog'),
          evaluationContext: EvaluationContext.empty,
        ),
        FlagEvaluationDetails(flagKey: 'flag', value: true),
        HookHints(),
      ),
      returnsNormally,
    );
  });

  test(
    'reports a non-exposure and warns for a wrapper without the Datadog hooks',
    () async {
      final logger = _MockLogger();
      final (_, provider) = await start();
      await api.setProviderForDomainAndWait(
        'wrapped',
        _WrappingProvider(provider, forwardHooks: false, forwardMetadata: true),
      );
      final wrapped = <ExposureEvaluation>[];
      api.addHooks([exposureHookWithLogger(wrapped.add, logger)]);

      api.getClient('wrapped').getBooleanValue('plain', false);
      api.getClient('wrapped').getBooleanValue('plain', false);
      await api.shutdown();

      expect([for (final e in wrapped) e.isExposure], [false, false]);
      verify(() => logger.warning(any())).called(1);
      expect(exposureEvents(), isEmpty);
    },
  );

  test('logs nothing for Datadog evaluations without an exposure', () async {
    final logger = _MockLogger();
    final (client, _) = await start(
      hook: exposureHookWithLogger(evaluations.add, logger),
    );

    client.getBooleanValue('silent', false);
    client.getStringValue('plain', 'default');

    expect([for (final e in evaluations) e.isExposure], [false, false]);
    verifyNever(() => logger.warning(any()));
  });

  test('skips the callback for a wrapper with its own metadata', () async {
    final (_, provider) = await start();
    await api.setProviderForDomainAndWait(
      'wrapped',
      _WrappingProvider(provider, forwardHooks: true, forwardMetadata: false),
    );

    api.getClient('wrapped').getBooleanValue('plain', false);
    await api.shutdown();

    expect(evaluations, isEmpty);
    expect(exposureEvents(), hasLength(1));
  });

  test('warns once for each other provider, up to eight', () async {
    final logger = _MockLogger();
    api.addHooks([exposureHookWithLogger(evaluations.add, logger)]);
    for (var i = 0; i < 9; i++) {
      await api.setProviderForDomainAndWait(
        'other-$i',
        _OtherProvider('Other $i'),
      );
      api.getClient('other-$i').getBooleanValue('flag', false);
      api.getClient('other-$i').getBooleanValue('flag', false);
    }

    verify(() => logger.warning(any())).called(8);
  });

  test('skips evaluations from other providers', () async {
    final logger = _MockLogger();
    await api.setProviderForDomainAndWait('other', _OtherProvider());
    api.addHooks([exposureHookWithLogger(evaluations.add, logger)]);

    api.getClient('other').getBooleanValue('flag', false);
    api.getClient('other').getBooleanValue('flag', false);

    expect(evaluations, isEmpty);
    verify(() => logger.warning(any())).called(1);
  });

  test('adds EXPOSURE features to the exposure event only', () async {
    final (client, _) = await start();

    client.getBooleanValue('flag', false);
    client.getBooleanValue('plain', false);
    await api.shutdown();

    final events = {
      for (final event in exposureEvents())
        (event['flag']! as Map)['key']: event,
    };
    expect(events['flag']!['features'], {'exposure.only': 'e'});
    expect(events['plain']!.containsKey('features'), isFalse);
  });

  test('splits evaluation counts by EVALUATION features', () async {
    final (client, provider) = await start();

    client.getBooleanValue('flag', false);
    client.getBooleanValue('flag', false);
    flags = {
      'flag': assignment(
        features: [
          feature('evaluation.only', 4, ['EVALUATION']),
        ],
      ),
    };
    await provider.refresh();
    client.getBooleanValue('flag', false);
    await api.shutdown();

    final rows = [
      for (final event in evaluationEvents())
        {'features': event['features'], 'count': event['evaluation_count']},
    ];
    expect(
      rows,
      unorderedEquals([
        {
          'features': {'evaluation.only': 3.0},
          'count': 2,
        },
        {
          'features': {'evaluation.only': 4.0},
          'count': 1,
        },
      ]),
    );
  });

  group('DatadogFlagsClient', () {
    late DatadogFlagsClient client;

    setUp(() async {
      final owner = DatadogFlags();
      addTearDown(owner.disable);
      await owner.enable(
        configuration: DatadogFlagsConfiguration(
          datadogConfig: datadogConfig,
          httpClient: httpClient(),
        ),
      );
      client = owner.sharedClient();
      await client.initialize(
        const FlagsEvaluationContext(targetingKey: 'user-1'),
      );
    });

    test('puts features in metadata and records the exposure', () async {
      final details = client.getBooleanDetails(
        key: 'flag',
        defaultValue: false,
      );
      client.getBooleanDetails(key: 'flag', defaultValue: false);
      await client.shutdown();

      expect(details.flagMetadata, {
        'datadog.allocation_key': 'allocation-a',
        'datadog.serial_id': 1,
        '__dd_feature.holdout.key': 'holdout-1',
        '__dd_feature.holdout.assignment_group': 'status_quo',
        '__dd_feature.holdout.should_include_in_holdout_analysis': false,
        '__dd_exposure_feature.exposure.only': 'e',
        '__dd_evaluation_feature.evaluation.only': 3.0,
      });
      expect(exposureEvents(), hasLength(1));
    });
  });

  group('ExposureLogger', () {
    final flagAssignment = FlagAssignment.fromJson(assignment());
    const subject = FlagsEvaluationContext(targetingKey: 'user-1');

    for (final trackExposures in [true, false]) {
      test('records the cache with trackExposures $trackExposures', () async {
        final logger = ExposureLogger(
          FlagsRuntime(
            configuration: DatadogFlagsConfiguration(
              trackExposures: trackExposures,
            ),
            datadogConfig: datadogConfig,
            httpClient: httpClient(),
          ),
        );

        bool log() => logger.logExposure(
          flagKey: 'plain',
          assignment: flagAssignment,
          evaluationContext: subject,
        );

        expect(log(), isFalse);
        expect(log(), isTrue);
        await logger.shutdown();
        expect(exposureEvents(), hasLength(trackExposures ? 1 : 0));
      });
    }
  });

  test('the fetcher warns once for each unknown destination', () async {
    final logger = _MockLogger();
    flags = {
      'flag': assignment(features: holdoutFeatures),
      'other': assignment(
        features: [
          feature('a', 'v', ['FUTURE', 'LATER']),
        ],
      ),
    };
    final fetcher = FlagAssignmentsFetcher(
      datadogConfig: datadogConfig,
      configuration: const DatadogFlagsConfiguration(),
      httpClient: httpClient(),
      logger: logger,
    );

    await fetcher.fetch(const FlagsEvaluationContext(targetingKey: 'user-1'));
    await fetcher.fetch(const FlagsEvaluationContext(targetingKey: 'user-1'));

    final messages = verify(
      () => logger.warning(captureAny()),
    ).captured.cast<String>();
    expect(messages, hasLength(2));
    expect(messages.join(), allOf(contains('"FUTURE"'), contains('"LATER"')));
  });
}

final class _NestedEvaluationHook extends HookAdapter {
  final OpenFeatureClient _client;
  bool _nested = false;

  _NestedEvaluationHook(this._client);

  @override
  void after(
    HookContext context,
    FlagEvaluationDetails<Object> details,
    HookHints hints,
  ) {
    if (_nested) return;
    _nested = true;
    _client.getBooleanValue(context.flagKey, false);
  }
}

final class _DirectResolveHook extends HookAdapter {
  final DatadogOpenFeatureProvider _provider;

  _DirectResolveHook(this._provider);

  @override
  void after(
    HookContext context,
    FlagEvaluationDetails<Object> details,
    HookHints hints,
  ) {
    _provider.resolveBooleanValue('plain', false, EvaluationContext.empty);
  }
}

final class _WrappingProvider implements FeatureProvider, ProviderHooks {
  final DatadogOpenFeatureProvider _delegate;
  final bool _forwardHooks;
  final bool _forwardMetadata;

  _WrappingProvider(
    this._delegate, {
    required bool forwardHooks,
    required bool forwardMetadata,
  }) : _forwardHooks = forwardHooks,
       _forwardMetadata = forwardMetadata;

  @override
  ProviderMetadata get metadata => _forwardMetadata
      ? _delegate.metadata
      : const ProviderMetadata(name: 'Wrapper');

  @override
  List<Hook> get hooks => _forwardHooks ? _delegate.hooks : const [];

  @override
  ResolutionDetails<bool> resolveBooleanValue(
    String flagKey,
    bool defaultValue,
    EvaluationContext context,
  ) => _delegate.resolveBooleanValue(flagKey, defaultValue, context);

  @override
  ResolutionDetails<double> resolveDoubleValue(
    String flagKey,
    double defaultValue,
    EvaluationContext context,
  ) => _delegate.resolveDoubleValue(flagKey, defaultValue, context);

  @override
  ResolutionDetails<int> resolveIntegerValue(
    String flagKey,
    int defaultValue,
    EvaluationContext context,
  ) => _delegate.resolveIntegerValue(flagKey, defaultValue, context);

  @override
  ResolutionDetails<String> resolveStringValue(
    String flagKey,
    String defaultValue,
    EvaluationContext context,
  ) => _delegate.resolveStringValue(flagKey, defaultValue, context);

  @override
  ResolutionDetails<Map<String, Object?>> resolveStructureValue(
    String flagKey,
    Map<String, Object?> defaultValue,
    EvaluationContext context,
  ) => _delegate.resolveStructureValue(flagKey, defaultValue, context);
}
