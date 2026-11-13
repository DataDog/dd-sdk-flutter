// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'fixtures/flag-selection/selection_vectors.dart';

void main() {
  test('compiled selection vectors match the mirrored JSON file', () async {
    // Test runners start in the package directory.
    final file = File('test/fixtures/flag-selection/selection-vectors.json');

    expect(
      jsonDecode(selectionVectorsJson),
      jsonDecode(await file.readAsString()),
    );
  });
}
