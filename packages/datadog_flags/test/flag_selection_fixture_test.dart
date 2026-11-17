// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

import 'fixtures/flag-selection/selection_vectors.dart';

void main() {
  test('compiled selection vectors match the mirrored JSON file', () async {
    final file = File.fromUri(
      (await _packageRoot()).uri.resolve(
        'test/fixtures/flag-selection/selection-vectors.json',
      ),
    );

    expect(
      jsonDecode(selectionVectorsJson),
      jsonDecode(await file.readAsString()),
    );
  });
}

Future<Directory> _packageRoot() async {
  try {
    final libraryUri = await Isolate.resolvePackageUri(
      Uri.parse('package:datadog_flags/datadog_flags.dart'),
    );
    if (libraryUri != null) {
      return File.fromUri(libraryUri).parent.parent;
    }
  } on UnsupportedError {
    // `flutter test` does not support package URI resolution.
  }

  for (final candidate in [
    Directory.current,
    Directory.fromUri(Directory.current.uri.resolve('packages/datadog_flags/')),
  ]) {
    if (File.fromUri(
      candidate.uri.resolve('lib/datadog_flags.dart'),
    ).existsSync()) {
      return candidate;
    }
  }
  throw StateError('Could not find the datadog_flags package root.');
}
