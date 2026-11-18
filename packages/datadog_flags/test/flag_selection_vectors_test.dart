// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/src/flag_selection.dart';
import 'package:test/test.dart';

import 'fixtures/flag-selection/selection_vectors.dart';

void main() {
  final vectors = jsonDecode(selectionVectorsJson) as Map<String, Object?>;
  final cases = (vectors['cases'] as List<Object?>)
      .cast<Map<String, Object?>>();

  for (final vector in cases) {
    final name = vector['name'] as String;
    final sdk = vector['sdk'] as Map<String, Object?>?;
    test(
      name,
      () {
        final query = vector['query'] as Map<String, Object?>;
        final result = canonicalizeFlagSelection(
          FlagSelection(
            tags: _strings(query['selected_flag_tags']),
            keyPatterns: _strings(query['selected_flag_key_patterns']),
          ),
        );

        final dropped = sdk!['dropped'] as String?;
        if (dropped != null) {
          expect(result.selection, isNull);
          expect(result.error?.reason, dropped);
          return;
        }
        final expected = sdk['selection'] as Map<String, Object?>;
        final tags = _strings(expected['tags']);
        final keyPatterns = _strings(expected['keyPatterns']);
        expect(result.error, isNull);
        if (tags.isEmpty && keyPatterns.isEmpty) {
          expect(result.selection, isNull);
        } else {
          expect(result.selection?.tags, tags);
          expect(result.selection?.keyPatterns, keyPatterns);
        }
      },
      skip: sdk == null
          ? 'rawQuery case: covers URL decoding, which the POST body does not use'
          : false,
    );
  }
}

List<String> _strings(Object? value) =>
    (value as List<Object?>? ?? const []).cast<String>();
