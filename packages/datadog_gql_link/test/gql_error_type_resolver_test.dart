// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_gql_link/datadog_gql_link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gql/language.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';

class CustomServerException extends ServerException {
  const CustomServerException();
}

void main() {
  final errors = <String, Object>{
    'ServerException': const ServerException(),
    'RequestFormatException': RequestFormatException(
      request: Request(
        operation: Operation(document: parseString('query { id }')),
      ),
    ),
    'ResponseFormatException': const ResponseFormatException(),
    'ContextReadException': const ContextReadException(),
    'ContextWriteException': const ContextWriteException(),
  };

  for (final MapEntry(key: type, value: error) in errors.entries) {
    test('resolves $type to its unobfuscated runtimeType', () {
      expect(gqlErrorTypeResolver(error), type);
      expect(gqlErrorTypeResolver(error), error.runtimeType.toString());
    });
  }

  test('does not resolve subclasses of gql_link exceptions', () {
    expect(gqlErrorTypeResolver(const CustomServerException()), isNull);
  });

  test('does not resolve other errors', () {
    expect(gqlErrorTypeResolver(const FormatException('format')), isNull);
    expect(gqlErrorTypeResolver(StateError('state')), isNull);
  });
}
