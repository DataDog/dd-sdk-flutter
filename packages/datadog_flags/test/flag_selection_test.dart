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

void main() {
  const datadogConfig = DatadogFlagsConfig(
    clientToken: 'client-token',
    env: 'staging',
    site: DatadogFlagsSite.us1,
  );
  const evaluationContext = FlagsEvaluationContext(targetingKey: 'user-1');
  const ignoredHeader = 'dd-flag-selection-ignored';

  FlagAssignmentsFetcher createFetcher(
    FlagSelection? selection,
    http.Client client,
    FlagsLogger logger,
  ) {
    return FlagAssignmentsFetcher(
      datadogConfig: datadogConfig,
      configuration: DatadogFlagsConfiguration(flagSelection: selection),
      httpClient: client,
      logger: logger,
    );
  }

  FlagsRepository createRepository(
    FlagSelection? selection,
    http.Client client,
    FlagsLogger logger, {
    DatadogFlagsStore? store,
  }) {
    return FlagsRepository(
      clientName: 'default',
      fetcher: createFetcher(selection, client, logger),
      store: store,
      dateProvider: () => DateTime.utc(2026),
      logger: logger,
    );
  }

  FlagsData snapshot(FlagSelection? selection) {
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
      'context': evaluationContext.toJson(),
      'date': DateTime.utc(2026).toIso8601String(),
    }).withSelection(selection);
  }

  group('canonicalizeFlagSelection', () {
    for (final value in ['a\uD800', '\uDC00a', 'a\uD800b', '\uDC00\uD800']) {
      final codeUnits = value.codeUnits.map(_unicodeLabel).join(' ');
      for (final (field, selection) in [
        ('tags', FlagSelection(tags: [value])),
        ('keyPatterns', FlagSelection(keyPatterns: [value])),
      ]) {
        test('drops unpaired surrogates in $field ($codeUnits) as '
            'malformed_selection', () {
          final result = canonicalizeFlagSelection(selection);
          expect(result.selection, isNull);
          expect(result.error, FlagSelectionError.malformedSelection);
        });
      }
    }

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

    // The 25 White_Space code points of the Unicode Character Database:
    // https://www.unicode.org/Public/UCD/latest/ucd/PropList.txt
    const whiteSpace = [
      0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0x85, 0xA0, 0x1680, 0x2000, //
      0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008, //
      0x2009, 0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000,
    ];
    for (final codePoint in whiteSpace) {
      test('trims White_Space ${_unicodeLabel(codePoint)}', () {
        final space = String.fromCharCode(codePoint);
        final result = canonicalizeFlagSelection(
          FlagSelection(tags: ['${space}a${space}b$space', space]),
        );
        expect(result.selection?.tags, ['a${space}b']);
      });
    }
    for (final codePoint in [0x1C, 0x1F, 0x180E, 0x200B, 0xFEFF]) {
      test('keeps non-White_Space ${_unicodeLabel(codePoint)}', () {
        final other = String.fromCharCode(codePoint);
        final result = canonicalizeFlagSelection(
          FlagSelection(tags: ['${other}a$other']),
        );
        expect(result.selection?.tags, ['${other}a$other']);
      });
    }

    for (final (description, selection) in <(String, FlagSelection?)>[
      ('null', null),
      ('no lists', const FlagSelection()),
      (
        'lists that trim to empty',
        const FlagSelection(tags: [' ', ''], keyPatterns: ['　']),
      ),
    ]) {
      test('returns no selection for $description', () {
        final result = canonicalizeFlagSelection(selection);
        expect(result.selection, isNull);
        expect(result.error, isNull);
      });
    }
  });

  group('flagSelectionIgnoredReason', () {
    for (final reason in [
      'malformed_selection',
      'too_many_values',
      'invalid_key_pattern',
      'invalid_tag',
      'tag_load_failed',
    ]) {
      test('reports the known reason $reason', () {
        expect(flagSelectionIgnoredReason({ignoredHeader: reason}), reason);
      });
    }

    for (final value in [
      'Too_Many_Values',
      ' too_many_values',
      'too_many_values, too_many_values',
      'unknown_reason',
      'x' * 33,
      'too_many_values${' ' * 30}',
    ]) {
      test('reports ${jsonEncode(value)} as unknown', () {
        expect(flagSelectionIgnoredReason({ignoredHeader: value}), 'unknown');
      });
    }

    test('treats a missing or empty header as absent', () {
      expect(flagSelectionIgnoredReason(const {}), isNull);
      expect(flagSelectionIgnoredReason({ignoredHeader: ''}), isNull);
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
          ignoredHeader: 'invalid_tag',
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
      final fetcher = createFetcher(
        const FlagSelection(
          tags: [' team:b ', 'team:a', 'team:a'],
          keyPatterns: ['checkout.*'],
        ),
        _client(requests),
        logger,
      );

      await fetcher.fetch(evaluationContext);

      final attributes = _attributes(requests.single);
      expect(attributes['flag_selection'], {
        'tags': ['team:a', 'team:b'],
        'key_patterns': ['checkout.*'],
      });
      expect(attributes.keys, ['env', 'source', 'subject', 'flag_selection']);
      verifyNever(() => logger.error(any()));
    });

    for (final (description, selection) in <(String, FlagSelection?)>[
      ('no selection', null),
      ('a selection that trims to empty', const FlagSelection(tags: [' '])),
      ('a dropped selection', FlagSelection(tags: ['a' * 201])),
    ]) {
      test('sends no flag_selection for $description', () async {
        final requests = <http.Request>[];
        await createFetcher(
          selection,
          _client(requests),
          logger,
        ).fetch(evaluationContext);
        expect(
          _attributes(requests.single).containsKey('flag_selection'),
          isFalse,
        );
      });
    }

    test('logs a dropped selection once per client', () async {
      final requests = <http.Request>[];
      final fetcher = createFetcher(
        FlagSelection(keyPatterns: [for (var i = 0; i < 32; i++) 'k$i']),
        _client(requests),
        logger,
      );
      await fetcher.fetch(evaluationContext);
      await fetcher.fetch(evaluationContext);

      verify(
        () => logger.error(
          'flagSelection was not sent (too_many_values: each list accepts at '
          'most 31 values). Loading the full flag configuration.',
        ),
      ).called(1);
      expect(fetcher.flagSelection, isNull);
    });

    test(
      'logs a dropped selection once per provider across its clients',
      () async {
        final dropLog = FlagSelectionDropLog();
        final selection = FlagSelection(
          keyPatterns: [for (var i = 0; i < 32; i++) 'k$i'],
        );
        for (var revision = 0; revision < 3; revision++) {
          final fetcher = FlagAssignmentsFetcher(
            datadogConfig: datadogConfig,
            configuration: DatadogFlagsConfiguration(flagSelection: selection),
            httpClient: _client(<http.Request>[]),
            logger: logger,
            dropLog: dropLog,
          );
          await fetcher.fetch(evaluationContext);
          expect(fetcher.flagSelection, isNull);
        }

        verify(
          () => logger.error(
            'flagSelection was not sent (too_many_values: each list accepts at '
            'most 31 values). Loading the full flag configuration.',
          ),
        ).called(1);
      },
    );

    test('shares a drop log with the clients of a provider owner', () {
      final owner = DatadogFlags();
      expect(flagSelectionDropLogFor(owner), isNull);
      final dropLog = FlagSelectionDropLog();
      shareFlagSelectionDropLog(owner, dropLog);
      expect(flagSelectionDropLogFor(owner), same(dropLog));
    });

    for (final (reason, selection, limit) in [
      (
        'malformed_selection',
        const FlagSelection(tags: ['\uD800']),
        'malformed_selection: flagSelection must be an object with '
            'optional tags and keyPatterns string arrays',
      ),
      (
        'invalid_key_pattern',
        FlagSelection(keyPatterns: ['k' * 201]),
        'invalid_key_pattern: each key pattern is at most 200 UTF-8 bytes',
      ),
      (
        'invalid_tag',
        FlagSelection(tags: ['t' * 201]),
        'invalid_tag: each tag is at most 200 UTF-8 bytes',
      ),
    ]) {
      test('logs the limit text for a $reason drop', () {
        createFetcher(selection, _client([]), logger);
        verify(
          () => logger.error(
            'flagSelection was not sent ($limit). '
            'Loading the full flag configuration.',
          ),
        ).called(1);
      });
    }

    test('reads the ignored header only when a selection was sent', () async {
      final headers = {ignoredHeader: 'tag_load_failed'};
      final selected = await createFetcher(
        const FlagSelection(tags: ['team:a']),
        _client([], headers: headers),
        logger,
      ).fetch(evaluationContext);
      final unselected = await createFetcher(
        null,
        _client([], headers: headers),
        logger,
      ).fetch(evaluationContext);

      expect(selected.flagSelectionIgnoredReason, 'tag_load_failed');
      expect(unselected.flagSelectionIgnoredReason, isNull);
    });

    for (final (description, response) in [
      (
        'a 500 response',
        http.Response('{}', 500, headers: {ignoredHeader: 'invalid_tag'}),
      ),
      (
        'a 200 response that is not JSON',
        http.Response('not json', 200, headers: {ignoredHeader: 'invalid_tag'}),
      ),
    ]) {
      test('does not report the header for $description', () async {
        final fetcher = createFetcher(
          const FlagSelection(tags: ['team:a']),
          MockClient((_) async => response),
          logger,
        );
        await expectLater(fetcher.fetch(evaluationContext), throwsA(anything));
      });
    }
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
      repository = createRepository(
        const FlagSelection(tags: ['team:a']),
        _client([], headers: {ignoredHeader: 'too_many_values'}),
        logger,
      );

      await repository.initialize(evaluationContext);

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
      await createRepository(
        const FlagSelection(tags: ['team:b', ' team:a ']),
        _client([]),
        logger,
        store: store,
      ).initialize(evaluationContext);

      final stored = await store.read('default');
      expect(stored?.flagSelection?.tags, ['team:a', 'team:b']);
      expect(stored?.flagSelection?.keyPatterns, isEmpty);
    });

    const selectionA = FlagSelection(tags: ['team:a']);
    const selectionB = FlagSelection(tags: ['team:b']);
    for (final (description, storedUnder, configured, restored)
        in <(String, FlagSelection?, FlagSelection?, bool)>[
          ('the same selection', selectionA, selectionA, true),
          (
            'an equivalent selection',
            selectionA,
            const FlagSelection(tags: [' team:a', 'team:a']),
            true,
          ),
          ('a different selection', selectionA, selectionB, false),
          ('no selection over a selected snapshot', selectionA, null, false),
          ('a selection over an unselected snapshot', null, selectionA, false),
          ('no selection over an unselected snapshot', null, null, true),
        ]) {
      test('${restored ? 'restores' : 'does not restore'} a snapshot under '
          '$description', () async {
        final store = InMemoryDatadogFlagsStore();
        await store.write(
          'default',
          snapshot(canonicalizeFlagSelection(storedUnder).selection),
        );
        final repository = createRepository(
          configured,
          MockClient((_) async => http.Response('', 503)),
          logger,
          store: store,
        );

        await repository.initialize(evaluationContext);

        expect(repository.flagAssignment('cached-flag') != null, restored);
      });
    }
  });

  group('FlagsData persistence with a flag selection', () {
    const selection = FlagSelection(tags: ['team:a'], keyPatterns: ['k*']);

    test('writes selected assignments under a key older SDKs do not read', () {
      final json = snapshot(selection).toJson();

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
      final json = snapshot(null).toJson();
      expect(json.keys, ['flags', 'context', 'date']);
      expect(FlagsData.fromJson(json).flagSelection, isNull);
    });

    for (final (description, value) in <(String, Object?)>[
      ('a string', 'team:a'),
      (
        'tags that are not a list',
        {'tags': 'team:a', 'keyPatterns': <String>[]},
      ),
      ('missing keyPatterns', {'tags': <String>[]}),
      (
        'a tag that is not a string',
        {
          'tags': [1],
          'keyPatterns': <String>[],
        },
      ),
    ]) {
      test('rejects a stored selection with $description', () {
        final json = snapshot(selection).toJson();
        expect(
          () => FlagsData.fromJson({...json, 'flagSelection': value}),
          throwsA(anything),
        );
      });
    }

    test('rejects a selected snapshot without selectedFlags', () {
      final json = snapshot(selection).toJson();
      expect(
        () => FlagsData.fromJson({...json}..remove('selectedFlags')),
        throwsA(anything),
      );
    });
  });
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

String _unicodeLabel(int codeUnit) =>
    'U+${codeUnit.toRadixString(16).toUpperCase().padLeft(4, '0')}';

extension on FlagsData {
  FlagsData withSelection(FlagSelection? selection) => FlagsData(
    flags: flags,
    context: context,
    date: date,
    obfuscation: obfuscation,
    flagSelection: selection,
  );
}
