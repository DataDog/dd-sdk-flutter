// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_tracking_http_client/datadog_tracking_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements HttpClient {}

class CustomClientException extends http.ClientException {
  CustomClientException(super.message);
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  test('resolves ClientException', () {
    final error = http.ClientException('client error');

    expect(httpErrorTypeResolver(error), 'ClientException');
    expect(httpErrorTypeResolver(error), error.runtimeType.toString());
  });

  test('resolves socket errors thrown by IOClient', () async {
    final inner = MockHttpClient();
    when(
      () => inner.openUrl(any(), any()),
    ).thenThrow(const SocketException('Connection refused'));

    final client = IOClient(inner);
    Object? error;
    try {
      await client.get(Uri.parse('http://localhost/'));
    } catch (e) {
      error = e;
    }

    expect(error, isA<http.ClientException>());
    expect(error, isA<SocketException>());
    expect(httpErrorTypeResolver(error!), '_ClientSocketException');
    expect(httpErrorTypeResolver(error), error.runtimeType.toString());
  });

  test('does not resolve other subclasses of ClientException', () {
    expect(httpErrorTypeResolver(CustomClientException('custom')), isNull);
  });

  test('does not resolve other errors', () {
    expect(httpErrorTypeResolver(const SocketException('socket')), isNull);
    expect(httpErrorTypeResolver(StateError('state')), isNull);
  });
}
