// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/assignment.dart';
import 'package:datadog_flags/src/flag_assignments_fetcher.dart';
import 'package:datadog_flags/src/precompute_response.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  for (final fixtureFileName in _fixtureFileNames) {
    test(
      'mirrored canonical precompute fixture $fixtureFileName parses',
      () async {
        final fixture = await _fixtureCase(fixtureFileName);
        final assignments = await _fetchAssignments(fixture);
        final expectedAssignments = _flagsFrom(fixture);

        expect(assignments.keys, expectedAssignments.keys);

        for (final entry in expectedAssignments.entries) {
          final assignment = assignments[entry.key];
          final expectedAssignment = entry.value;
          expect(assignment, isNotNull);
          expect(assignment!.allocationKey, expectedAssignment.allocationKey);
          expect(assignment.variationKey, expectedAssignment.variationKey);
          expect(assignment.variationType, expectedAssignment.variationType);
          expect(assignment.variationValue, expectedAssignment.variationValue);
          expect(assignment.reason, expectedAssignment.reason);
          expect(assignment.doLog, expectedAssignment.doLog);
        }
      },
    );
  }
}

const _fixtureFileNames = [
  'all-types-success.json',
  'defaults-and-emission-gates.json',
];

Future<Map<String, Object?>> _fixtureCase(String fileName) async {
  final file = File.fromUri(
    (await _packageRoot()).uri.resolve(
          'test/fixtures/precomputed/cases/$fileName',
        ),
  );
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
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
    // Some runners do not support package URI resolution.
  }

  return _packageRootFromCurrentDirectory();
}

Directory _packageRootFromCurrentDirectory() {
  if (_isDatadogFlagsPackage(Directory.current)) {
    return Directory.current;
  }

  final nested = Directory.fromUri(
    Directory.current.uri.resolve('packages/datadog_flags/'),
  );
  if (_isDatadogFlagsPackage(nested)) {
    return nested;
  }

  throw StateError('Could not find datadog_flags package root.');
}

bool _isDatadogFlagsPackage(Directory directory) {
  return File.fromUri(directory.uri.resolve('pubspec.yaml')).existsSync() &&
      File.fromUri(directory.uri.resolve('lib/datadog_flags.dart'))
          .existsSync();
}

Future<Map<String, FlagAssignment>> _fetchAssignments(
  Map<String, Object?> fixture,
) async {
  final fetcher = FlagAssignmentsFetcher(
    datadogConfig: const DatadogFlagsConfig(
      clientToken: 'client-token',
      env: 'staging',
      site: DatadogFlagsSite.us1,
    ),
    configuration: const DatadogFlagsConfiguration(),
    httpClient: MockClient((_) async {
      return http.Response(jsonEncode(fixture['response']), 200);
    }),
  );

  return (await fetcher.fetch(
    FlagsEvaluationContext.fromJson(
      fixture['context'] as Map<String, Object?>,
    ),
  ))
      .flags;
}

Map<String, FlagAssignment> _flagsFrom(Map<String, Object?> fixture) {
  final response = PrecomputeResponse.fromJson(
    Map<String, Object?>.from(fixture['response'] as Map),
  );
  return response.data.attributes.flags;
}
