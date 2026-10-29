// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:io';

import 'package:datadog_flutter_plugin/src/error_type_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

class CustomException implements Exception {}

class CustomSocketException extends SocketException {
  CustomSocketException(super.message);
}

class CustomTlsException extends TlsException {
  CustomTlsException(super.message);
}

void main() {
  group('defaultErrorTypeResolver', () {
    final knownErrors = <String, Object>{
      'TimeoutException': TimeoutException('timeout'),
      'FormatException': const FormatException('format'),
      'SocketException': const SocketException('socket'),
      'HttpException': const HttpException('http'),
      'WebSocketException': const WebSocketException('websocket'),
      'HandshakeException': const HandshakeException('handshake'),
      'CertificateException': const CertificateException('certificate'),
      'TlsException': const TlsException('tls'),
      'OSError': const OSError('os', 1),
    };

    for (final MapEntry(key: type, value: error) in knownErrors.entries) {
      test('resolves $type to its unobfuscated runtimeType', () {
        expect(defaultErrorTypeResolver(error), type);
        expect(defaultErrorTypeResolver(error), error.runtimeType.toString());
      });
    }

    final unknownErrors = <String, Object>{
      'subclass of SocketException': CustomSocketException('custom'),
      'subclass of TlsException': CustomTlsException('custom'),
      'custom exception': CustomException(),
      'string': 'a string',
    };

    for (final MapEntry(key: description, value: error)
        in unknownErrors.entries) {
      test('does not resolve $description', () {
        expect(defaultErrorTypeResolver(error), isNull);
      });
    }
  });

  group('ErrorTypeResolverRegistry', () {
    late ErrorTypeResolverRegistry registry;

    setUp(() {
      registry = ErrorTypeResolverRegistry();
    });

    test('falls back to default resolver', () {
      expect(
        registry.resolve(const SocketException('socket')),
        'SocketException',
      );
    });

    test('falls back to runtimeType for unknown types', () {
      expect(registry.resolve(CustomException()), 'CustomException');
      expect(registry.tryResolve(CustomException()), isNull);
    });

    test('uses registered resolvers', () {
      registry.add((e) => e is CustomException ? 'MyCustomType' : null);

      expect(registry.resolve(CustomException()), 'MyCustomType');
      expect(registry.tryResolve(CustomException()), 'MyCustomType');
    });

    test('first non-null resolver wins, in registration order', () {
      final calls = <String>[];
      registry.add((e) {
        calls.add('first');
        return null;
      });
      registry.add((e) {
        calls.add('second');
        return 'Second';
      });
      registry.add((e) {
        calls.add('third');
        return 'Third';
      });

      expect(registry.resolve(CustomException()), 'Second');
      expect(calls, ['first', 'second']);
    });

    test('registered resolvers run before default resolver', () {
      registry.add((e) => e is SocketException ? 'OverriddenSocket' : null);

      expect(
        registry.resolve(const SocketException('socket')),
        'OverriddenSocket',
      );
    });

    test('resolvers can handle subclasses before superclasses', () {
      registry.add((e) => e is CustomSocketException ? 'CustomSocket' : null);
      registry.add((e) => e is SocketException ? 'AnySocket' : null);

      expect(registry.resolve(CustomSocketException('custom')), 'CustomSocket');
      expect(registry.resolve(const SocketException('socket')), 'AnySocket');
    });

    test('adding the same resolver twice registers it once', () {
      var callCount = 0;
      String? resolver(Object e) {
        callCount++;
        return null;
      }

      registry.add(resolver);
      registry.add(resolver);
      registry.resolve(CustomException());

      expect(callCount, 1);
    });

    test('skips resolvers that throw', () {
      registry.add((e) => throw StateError('broken resolver'));
      registry.add((e) => 'Resolved');

      expect(registry.resolve(CustomException()), 'Resolved');
    });
  });
}
