// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/assignment.dart';
import 'package:datadog_flags/src/flags_log.dart';
import 'package:datadog_flags/src/split_features.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements FlagsLogger {}

void main() {
  Map<String, Object?> feature(
    String key,
    Object? value, [
    Object? destinations = const ['HOOK'],
  ]) => {'key': key, 'value': value, 'destinations': destinations};

  Map<String, Object?> assignmentJson({Object? features}) => {
    'allocationKey': 'allocation-a',
    'variationKey': 'on',
    'variationType': 'boolean',
    'variationValue': true,
    'reason': 'TARGETING_MATCH',
    'doLog': true,
    'serialId': 7,
    'features': ?features,
  };

  group('SplitFeature.listFromJson', () {
    test('parses string, number, and boolean values', () {
      final features = SplitFeature.listFromJson([
        feature('holdout.key', 'h-1'),
        feature('ratio', 2),
        feature('share', 0.25),
        feature('holdout.should_include_in_holdout_analysis', false),
      ]);

      expect(
        {for (final feature in features) feature.key: feature.value},
        {
          'holdout.key': 'h-1',
          'ratio': 2.0,
          'share': 0.25,
          'holdout.should_include_in_holdout_analysis': false,
        },
      );
      expect(features[1].value, isA<double>());
    });

    final malformedFields = <String, Object?>{
      'missing': null,
      'an object': {'key': 'k'},
      'a string': 'HOOK',
      'a number': 1,
      'empty': <Object?>[],
    };
    for (final MapEntry(key: name, value: json) in malformedFields.entries) {
      test('treats $name `features` field as no features', () {
        expect(SplitFeature.listFromJson(json), isEmpty);
        final assignment = FlagAssignment.fromJson(
          assignmentJson(features: json),
        );
        expect(assignment.variationValue, isTrue);
        expect(assignment.features, isEmpty);
      });
    }

    final invalidEntries = <String, Object?>{
      'not an object': 'holdout.key',
      'missing key': {
        'value': 'v',
        'destinations': ['HOOK'],
      },
      'empty key': feature('', 'v'),
      'non-string key': {
        'key': 3,
        'value': 'v',
        'destinations': ['HOOK'],
      },
      'null value': feature('k', null),
      'list value': feature('k', ['v']),
      'object value': feature('k', {'v': 1}),
      'missing destinations': {'key': 'k', 'value': 'v'},
      'non-list destinations': feature('k', 'v', 'HOOK'),
      'empty destinations': feature('k', 'v', <Object?>[]),
      'only invalid destinations': feature('k', 'v', [1, '', null]),
    };
    for (final MapEntry(key: name, value: entry) in invalidEntries.entries) {
      test('skips a feature with $name and keeps the others', () {
        final features = SplitFeature.listFromJson([
          entry,
          feature('k', 'valid'),
        ]);
        expect(features, hasLength(1));
        expect(features.single.key, 'k');
        expect(features.single.value, 'valid');
      });
    }

    test('keeps the first valid feature for a repeated key', () {
      final features = SplitFeature.listFromJson([
        feature('k', 'first', ['HOOK']),
        feature('k', 'second', ['EXPOSURE', 'EVALUATION']),
      ]);
      expect(features, hasLength(1));
      expect(features.single.value, 'first');
      expect(features.forDestination(SplitFeatureDestination.exposure), {});
    });

    test('keeps unknown destinations in the model', () {
      final features = SplitFeature.listFromJson([
        feature('k', 'v', ['FUTURE', 'HOOK', 7]),
      ]);
      expect(features.single.destinations, ['FUTURE', 'HOOK']);
    });
  });

  group('SplitFeatureList', () {
    final features = SplitFeature.listFromJson([
      feature('hook', 'h', ['HOOK']),
      feature('exposure', 1, ['EXPOSURE']),
      feature('evaluation', true, ['EVALUATION']),
      feature('all', 'a', ['HOOK', 'EXPOSURE', 'EVALUATION']),
      feature('nowhere', 'n', ['FUTURE', 'hook']),
    ]);

    test('routes each feature to its destinations', () {
      expect(features.forDestination(SplitFeatureDestination.hook), {
        'hook': 'h',
        'all': 'a',
      });
      expect(features.forDestination(SplitFeatureDestination.exposure), {
        'exposure': 1.0,
        'all': 'a',
      });
      expect(features.forDestination(SplitFeatureDestination.evaluation), {
        'evaluation': true,
        'all': 'a',
      });
    });

    test('writes one metadata entry per feature and destination', () {
      expect(features.toFlagMetadata(), {
        '__dd_feature.hook': 'h',
        '__dd_feature.all': 'a',
        '__dd_exposure_feature.exposure': 1.0,
        '__dd_exposure_feature.all': 'a',
        '__dd_evaluation_feature.evaluation': true,
        '__dd_evaluation_feature.all': 'a',
      });
    });

    test('reads features of one destination back from metadata', () {
      expect(
        splitFeaturesFromMetadata({
          ...features.toFlagMetadata(),
          'datadog.allocation_key': 'allocation-a',
        }, SplitFeatureDestination.hook),
        {'hook': 'h', 'all': 'a'},
      );
    });

    test('adds no metadata without features', () {
      expect(const <SplitFeature>[].toFlagMetadata(), isEmpty);
    });
  });

  group('persistence', () {
    test('stores features with assignments', () {
      final data = FlagsData(
        flags: {
          'flag': FlagAssignment.fromJson(
            assignmentJson(
              features: [
                feature('holdout.key', 'h-1'),
                feature('ratio', 2, ['EXPOSURE', 'FUTURE']),
              ],
            ),
          ),
        },
        context: const FlagsEvaluationContext(targetingKey: 'user'),
        date: DateTime.utc(2026),
      );

      final restored = FlagsData.fromJson(data.toJson()).flags['flag']!;

      expect(SplitFeature.listToJson(restored.features), [
        {
          'key': 'holdout.key',
          'value': 'h-1',
          'destinations': ['HOOK'],
        },
        {
          'key': 'ratio',
          'value': 2.0,
          'destinations': ['EXPOSURE', 'FUTURE'],
        },
      ]);
    });

    test('omits the field without features', () {
      final assignment = FlagAssignment.fromJson(assignmentJson());
      expect(assignment.toJson().containsKey('features'), isFalse);
    });
  });

  group('UnknownDestinationWarnings', () {
    late _MockLogger logger;
    late UnknownDestinationWarnings warnings;

    setUp(() {
      logger = _MockLogger();
      warnings = UnknownDestinationWarnings(logger);
    });

    test('warns once for each unknown destination', () {
      final features = SplitFeature.listFromJson([
        feature('a', 'v', ['HOOK', 'FUTURE']),
        feature('b', 'v', ['FUTURE', 'OTHER', 'EXPOSURE', 'EVALUATION']),
      ]);

      warnings.check(features);
      warnings.check(features);

      final messages = verify(
        () => logger.warning(captureAny()),
      ).captured.cast<String>();
      expect(messages, hasLength(2));
      expect(messages[0], contains('"FUTURE"'));
      expect(messages[1], contains('"OTHER"'));
    });

    test('stops warning after 64 distinct values', () {
      warnings.check(
        SplitFeature.listFromJson([
          for (var i = 0; i < 70; i++) feature('k$i', 'v', ['UNKNOWN_$i']),
        ]),
      );

      verify(
        () => logger.warning(any()),
      ).called(UnknownDestinationWarnings.maxWarnedValues);
    });
  });
}
