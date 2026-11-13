// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/flag_assignments_fetcher.dart';
import 'package:datadog_flags/src/flag_selection.dart';
import 'package:datadog_flags/src/flags_log.dart';
import 'package:datadog_flags/src/flags_repository.dart';
import 'package:datadog_flags/src/flags_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockFlagsLogger extends Mock implements FlagsLogger {}

const _datadogConfig = DatadogFlagsConfig(
  clientToken: 'client-token',
  env: 'staging',
  site: DatadogFlagsSite.us1,
);
const _context = FlagsEvaluationContext(targetingKey: 'user-1');
const _ignoredHeader = 'dd-flag-selection-ignored';

void main() {
  group('canonicalizeFlagSelection', () {
    test('drops unpaired surrogates as malformed_selection', () {
      for (final value in ['a\uD800', '\uDC00a', 'a\uD800b', '\uDC00\uD800']) {
        for (final selection in [
          FlagSelection(tags: [value]),
          FlagSelection(keyPatterns: [value]),
        ]) {
          final result = canonicalizeFlagSelection(selection);
          expect(result.selection, isNull);
          expect(result.error, FlagSelectionError.malformedSelection);
        }
      }
    });

    test('malformed_selection takes precedence over too_many_values', () {
      final result = canonicalizeFlagSelection(
        FlagSelection(
          tags: [for (var index = 0; index < 32; index++) 't$index'],
          keyPatterns: const ['\uD800'],
        ),
      );
      expect(result.error, FlagSelectionError.malformedSelection);
    });

    test('keeps surrogate pairs and sorts by UTF-8 bytes', () {
      final result = canonicalizeFlagSelection(
        const FlagSelection(tags: ['～', '\u{1F600}', 'a']),
      );
      expect(result.selection?.tags, ['a', '～', '\u{1F600}']);
    });

    test('trims exactly the 25 White_Space code points', () {
      const whiteSpace = [
        0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0x85, 0xA0, 0x1680, 0x2000, //
        0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008, //
        0x2009, 0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000,
      ];
      for (final codePoint in whiteSpace) {
        final space = String.fromCharCode(codePoint);
        final result = canonicalizeFlagSelection(
          FlagSelection(tags: ['${space}a${space}b$space', space]),
        );
        expect(result.selection?.tags, ['a${space}b'], reason: '$codePoint');
      }
      for (final codePoint in [0x1C, 0x1F, 0x180E, 0x200B, 0xFEFF]) {
        final other = String.fromCharCode(codePoint);
        final result = canonicalizeFlagSelection(
          FlagSelection(tags: ['${other}a$other']),
        );
        expect(result.selection?.tags, ['${other}a$other']);
      }
    });

    test('returns no selection for null and for empty lists', () {
      for (final selection in [
        null,
        const FlagSelection(),
        const FlagSelection(tags: [' ', ''], keyPatterns: ['　']),
      ]) {
        final result = canonicalizeFlagSelection(selection);
        expect(result.selection, isNull);
        expect(result.error, isNull);
      }
    });
  });

  group('flagSelectionIgnoredReason', () {
    test('reports the five known reasons', () {
      for (final reason in [
        'malformed_selection',
        'too_many_values',
        'invalid_key_pattern',
        'invalid_tag',
        'tag_load_failed',
      ]) {
        expect(flagSelectionIgnoredReason({_ignoredHeader: reason}), reason);
      }
    });

    test('reports other values as unknown', () {
      for (final value in [
        'Too_Many_Values',
        ' too_many_values',
        'too_many_values, too_many_values',
        'unknown_reason',
        'x' * 33,
        'too_many_values${' ' * 30}',
      ]) {
        expect(flagSelectionIgnoredReason({_ignoredHeader: value}), 'unknown');
      }
    });

    test('treats a missing or empty header as absent', () {
      expect(flagSelectionIgnoredReason(const {}), isNull);
      expect(flagSelectionIgnoredReason({_ignoredHeader: ''}), isNull);
    });

    test('matches the header name case-insensitively', () {
      expect(
        flagSelectionIgnoredReason({
          'DD-Flag-Selection-Ignored': 'invalid_tag',
        }),
        'invalid_tag',
      );
      expect(
        flagSelectionIgnoredReason({
          'DD-Flag-Selection-Ignored': 'invalid_tag',
          _ignoredHeader: 'invalid_tag',
        }),
        'unknown',
      );
    });
  });

  group('FlagAssignmentsFetcher with a flag selection', () {
    late _MockFlagsLogger logger;

    setUp(() => logger = _MockFlagsLogger());

    test('sends exactly flag_selection with tags and key_patterns', () async {
      final requests = <http.Request>[];
      final fetcher = _fetcher(
        const FlagSelection(
          tags: [' team:b ', 'team:a', 'team:a'],
          keyPatterns: ['checkout.*'],
        ),
        _client(requests),
        logger,
      );

      await fetcher.fetch(_context);

      final attributes = _attributes(requests.single);
      expect(attributes['flag_selection'], {
        'tags': ['team:a', 'team:b'],
        'key_patterns': ['checkout.*'],
      });
      expect(attributes.keys, ['env', 'source', 'subject', 'flag_selection']);
      verifyNever(() => logger.error(any()));
    });

    test('sends no flag_selection without a selection to send', () async {
      for (final selection in [
        null,
        const FlagSelection(tags: [' ']),
        FlagSelection(tags: ['a' * 201]),
      ]) {
        final requests = <http.Request>[];
        await _fetcher(selection, _client(requests), logger).fetch(_context);
        expect(
          _attributes(requests.single).containsKey('flag_selection'),
          isFalse,
        );
      }
    });

    test('logs a dropped selection once per client', () async {
      final requests = <http.Request>[];
      final fetcher = _fetcher(
        FlagSelection(keyPatterns: [for (var i = 0; i < 32; i++) 'k$i']),
        _client(requests),
        logger,
      );
      await fetcher.fetch(_context);
      await fetcher.fetch(_context);

      verify(
        () => logger.error(
          'flagSelection was not sent (too_many_values: each list accepts at '
          'most 31 values). Loading the full flag configuration.',
        ),
      ).called(1);
      expect(fetcher.flagSelection, isNull);
    });

    test('logs the limit text for each dropped reason', () {
      final cases = {
        const FlagSelection(tags: ['\uD800']):
            'malformed_selection: flagSelection must be an object with '
            'optional tags and keyPatterns string arrays',
        FlagSelection(keyPatterns: ['k' * 201]):
            'invalid_key_pattern: each key pattern is at most 200 UTF-8 bytes',
        FlagSelection(tags: ['t' * 201]):
            'invalid_tag: each tag is at most 200 UTF-8 bytes',
      };
      for (final MapEntry(key: selection, value: limit) in cases.entries) {
        _fetcher(selection, _client([]), logger);
        verify(
          () => logger.error(
            'flagSelection was not sent ($limit). '
            'Loading the full flag configuration.',
          ),
        ).called(1);
      }
    });

    test('reads the ignored header only when a selection was sent', () async {
      final headers = {_ignoredHeader: 'tag_load_failed'};
      final selected = await _fetcher(
        const FlagSelection(tags: ['team:a']),
        _client([], headers: headers),
        logger,
      ).fetch(_context);
      final unselected = await _fetcher(
        null,
        _client([], headers: headers),
        logger,
      ).fetch(_context);

      expect(selected.flagSelectionIgnoredReason, 'tag_load_failed');
      expect(unselected.flagSelectionIgnoredReason, isNull);
    });

    test('does not report the header without a decoded 2xx body', () async {
      for (final response in [
        http.Response('{}', 500, headers: {_ignoredHeader: 'invalid_tag'}),
        http.Response(
          'not json',
          200,
          headers: {_ignoredHeader: 'invalid_tag'},
        ),
      ]) {
        final fetcher = _fetcher(
          const FlagSelection(tags: ['team:a']),
          MockClient((_) async => response),
          logger,
        );
        await expectLater(fetcher.fetch(_context), throwsA(anything));
      }
    });
  });

  group('FlagsRepository with a flag selection', () {
    late _MockFlagsLogger logger;

    setUp(() => logger = _MockFlagsLogger());

    test('logs an ignored selection after installing assignments', () async {
      late FlagsRepository repository;
      final statusesAtLog = <DatadogFlagsClientStatus>[];
      when(() => logger.error(any())).thenAnswer((_) {
        statusesAtLog.add(repository.status);
      });
      repository = _repository(
        const FlagSelection(tags: ['team:a']),
        _client([], headers: {_ignoredHeader: 'too_many_values'}),
        logger,
      );

      await repository.initialize(_context);

      verify(
        () => logger.error(
          'flagSelection was ignored by the server (too_many_values). '
          'Loaded the full flag configuration.',
        ),
      ).called(1);
      expect(statusesAtLog, [DatadogFlagsClientStatus.ready]);
    });

    test('stores the canonical selection with fetched assignments', () async {
      final store = InMemoryDatadogFlagsStore();
      await _repository(
        const FlagSelection(tags: ['team:b', ' team:a ']),
        _client([]),
        logger,
        store: store,
      ).initialize(_context);

      final stored = await store.read('default');
      expect(stored?.flagSelection?.tags, ['team:a', 'team:b']);
      expect(stored?.flagSelection?.keyPatterns, isEmpty);
    });

    test('restores a snapshot only under the same selection', () async {
      const selectionA = FlagSelection(tags: ['team:a']);
      const selectionB = FlagSelection(tags: ['team:b']);
      final cases = <(FlagSelection?, FlagSelection?, bool)>[
        (selectionA, selectionA, true),
        (selectionA, const FlagSelection(tags: [' team:a', 'team:a']), true),
        (selectionA, selectionB, false),
        (selectionA, null, false),
        (null, selectionA, false),
        (null, null, true),
      ];
      for (final (storedUnder, configured, restored) in cases) {
        final store = InMemoryDatadogFlagsStore();
        await store.write(
          'default',
          _snapshot(canonicalizeFlagSelection(storedUnder).selection),
        );
        final repository = _repository(
          configured,
          MockClient((_) async => http.Response('', 503)),
          logger,
          store: store,
        );

        await repository.initialize(_context);

        expect(
          repository.flagAssignment('cached-flag') != null,
          restored,
          reason: '$storedUnder -> $configured',
        );
      }
    });
  });

  group('FlagsData persistence with a flag selection', () {
    const selection = FlagSelection(tags: ['team:a'], keyPatterns: ['k*']);

    test('writes selected assignments under a key older SDKs do not read', () {
      final json = _snapshot(selection).toJson();

      expect(json.containsKey('flags'), isFalse);
      expect(json.containsKey('encodedFlags'), isFalse);
      expect(json['flagSelection'], {
        'tags': ['team:a'],
        'keyPatterns': ['k*'],
      });
      expect((json['selectedFlags'] as Map).keys, ['cached-flag']);

      final restored = FlagsData.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, Object?>,
      );
      expect(restored.flagSelection?.tags, ['team:a']);
      expect(restored.flagSelection?.keyPatterns, ['k*']);
      expect(restored.flags.keys, ['cached-flag']);
    });

    test('writes snapshots without a selection unchanged', () {
      final json = _snapshot(null).toJson();
      expect(json.keys, ['flags', 'context', 'date']);
      expect(FlagsData.fromJson(json).flagSelection, isNull);
    });

    test('rejects a malformed stored selection', () {
      final json = _snapshot(selection).toJson();
      for (final value in [
        'team:a',
        {'tags': 'team:a', 'keyPatterns': <String>[]},
        {'tags': <String>[]},
        {
          'tags': [1],
          'keyPatterns': <String>[],
        },
      ]) {
        expect(
          () => FlagsData.fromJson({...json, 'flagSelection': value}),
          throwsA(anything),
        );
      }
      expect(
        () => FlagsData.fromJson({...json}..remove('selectedFlags')),
        throwsA(anything),
      );
    });
  });
}

FlagAssignmentsFetcher _fetcher(
  FlagSelection? selection,
  http.Client client,
  FlagsLogger logger,
) {
  return FlagAssignmentsFetcher(
    datadogConfig: _datadogConfig,
    configuration: DatadogFlagsConfiguration(flagSelection: selection),
    httpClient: client,
    logger: logger,
  );
}

FlagsRepository _repository(
  FlagSelection? selection,
  http.Client client,
  FlagsLogger logger, {
  DatadogFlagsStore? store,
}) {
  return FlagsRepository(
    clientName: 'default',
    fetcher: _fetcher(selection, client, logger),
    store: store,
    dateProvider: () => DateTime.utc(2026),
    logger: logger,
  );
}

http.Client _client(
  List<http.Request> requests, {
  Map<String, String> headers = const {},
}) {
  return MockClient((request) async {
    requests.add(request);
    return http.Response(
      jsonEncode({
        'data': {
          'attributes': {'flags': <String, Object?>{}},
        },
      }),
      200,
      headers: headers,
    );
  });
}

Map<String, Object?> _attributes(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, Object?>;
  final data = body['data'] as Map<String, Object?>;
  return data['attributes'] as Map<String, Object?>;
}

FlagsData _snapshot(FlagSelection? selection) {
  return FlagsData.fromJson({
    'flags': {
      'cached-flag': {
        'allocationKey': 'allocation',
        'variationKey': 'on',
        'variationType': 'boolean',
        'variationValue': true,
        'reason': 'TARGETING_MATCH',
        'doLog': true,
      },
    },
    'context': _context.toJson(),
    'date': DateTime.utc(2026).toIso8601String(),
  }).withSelection(selection);
}

extension on FlagsData {
  FlagsData withSelection(FlagSelection? selection) => FlagsData(
    flags: flags,
    context: context,
    date: date,
    obfuscation: obfuscation,
    flagSelection: selection,
  );
}
