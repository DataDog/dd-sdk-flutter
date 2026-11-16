// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/assignment.dart';
import 'package:datadog_flags/src/assignment_transport_io.dart';
import 'package:datadog_flags/src/flag_assignments_fetcher.dart';
import 'package:datadog_flags/src/flags_error.dart';
import 'package:datadog_flags/src/response_protection.dart';
import 'package:test/test.dart';

import 'tls_test_certificates.dart';

void main() {
  const datadogConfig = DatadogFlagsConfig(
    clientToken: 'client-token',
    env: 'test',
    site: DatadogFlagsSite.us1,
  );
  final assignmentsResponse = jsonEncode({
    'data': {
      'attributes': {
        'flags': {
          'flag': {
            'variationType': 'boolean',
            'variationValue': true,
            'variationKey': 'on',
            'allocationKey': 'allocation',
            'reason': 'TARGETING_MATCH',
            'doLog': false,
          },
        },
      },
    },
  });

  SecurityContext trustingTestCa() =>
      SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificatesBytes(utf8.encode(caCertificatePem));

  Future<_TlsServer> startServer({
    required String certificatePem,
    required String privateKeyPem,
    String intermediatesPem = '',
  }) async {
    final server = await _TlsServer.start(
      SecurityContext()
        ..useCertificateChainBytes(
          utf8.encode(certificatePem + intermediatesPem),
        )
        ..usePrivateKeyBytes(utf8.encode(privateKeyPem)),
      assignmentsResponse,
    );
    addTearDown(server.close);
    return server;
  }

  Future<PrecomputedAssignments> fetch(
    _TlsServer server, {
    Set<String> pins = const {},
    TlsPinningProfile? profile,
    SecurityContext? context,
  }) {
    final endpoint = Uri.parse(
      'https://localhost:${server.port}/precompute-assignments',
    );
    final configuration = DatadogFlagsConfiguration(
      datadogConfig: datadogConfig,
      customFlagsEndpoint: endpoint,
    );
    final policy = TlsPinningPolicy.forEndpoint(
      profile ??
          TlsPinningProfile(
            name: 'test',
            hosts: const {'localhost'},
            spkiSha256Pins: pins,
          ),
      endpoint,
    );
    final client = createTlsPinningHttpClient(
      policy,
      context: context ?? trustingTestCa(),
    );
    addTearDown(client.close);
    return FlagAssignmentsFetcher(
      datadogConfig: datadogConfig,
      configuration: configuration,
      httpClient: client,
      protection: AssignmentProtection(policyId: 'test', client: client),
    ).fetch(const FlagsEvaluationContext(targetingKey: 'user'));
  }

  Matcher failedWith<T>() =>
      isA<FlagsException>().having((error) => error.cause, 'cause', isA<T>());

  final servers = {
    'A (EC P-256)': (leafAEcCertificatePem, leafAEcPrivateKeyPem),
    'B (RSA 2048)': (leafBRsaCertificatePem, leafBRsaPrivateKeyPem),
  };
  for (final MapEntry(key: name, value: (certificate, key))
      in servers.entries) {
    test('A+B pins fetch assignments from server $name', () async {
      final server = await startServer(
        certificatePem: certificate,
        privateKeyPem: key,
      );

      final assignments = await fetch(
        server,
        pins: {leafAEcSpkiPin, leafBRsaSpkiPin},
      );

      expect(assignments.flags['flag']?.variationValue, true);
      expect(server.requestBytes, hasLength(1));
      expect(
        utf8.decode(server.requestBytes.single),
        startsWith('POST /precompute-assignments HTTP/1.1'),
      );
    });
  }

  final rejected = {
    'an A-only profile (A plus the issuing CA)': {leafAEcSpkiPin, caSpkiPin},
    'a profile with unrelated pins': {
      base64.encode(List.filled(32, 1)),
      base64.encode(List.filled(32, 2)),
    },
  };
  for (final MapEntry(key: name, value: pins) in rejected.entries) {
    test('$name fails against server B before any HTTP bytes', () async {
      final server = await startServer(
        certificatePem: leafBRsaCertificatePem,
        privateKeyPem: leafBRsaPrivateKeyPem,
      );

      await expectLater(
        fetch(server, pins: pins),
        throwsA(failedWith<TlsPinningException>()),
      );
      await server.connectionsClosed;

      expect(server.requestBytes.where((bytes) => bytes.isNotEmpty), isEmpty);
    });
  }

  test('matching pins do not bypass normal certificate validation', () async {
    final server = await startServer(
      certificatePem: leafBRsaCertificatePem,
      privateKeyPem: leafBRsaPrivateKeyPem,
    );

    await expectLater(
      fetch(
        server,
        pins: {leafAEcSpkiPin, leafBRsaSpkiPin},
        context: SecurityContext(withTrustedRoots: false),
      ),
      throwsA(failedWith<HandshakeException>()),
    );
    await server.connectionsClosed;
    expect(server.requestBytes.where((bytes) => bytes.isNotEmpty), isEmpty);
  });

  group('issuer pinning', () {
    const issuerProfile = TlsPinningProfile.issuer(
      name: 'test',
      hosts: {'localhost'},
      spkiSha256Pins: {issuerRootASpkiPin, issuerIntermediateSpkiPin},
      issuerCertificates: [issuerRootAPem, issuerIntermediateByRootAPem],
    );

    final renewedLeaves = {
      'leaf 1': (issuerLeaf1CertificatePem, issuerLeaf1PrivateKeyPem),
      'leaf 2 with a new key': (
        issuerLeaf2CertificatePem,
        issuerLeaf2PrivateKeyPem,
      ),
    };
    for (final MapEntry(key: name, value: (certificate, key))
        in renewedLeaves.entries) {
      test('accepts $name through the cross-signed intermediate', () async {
        // The server sends the root B intermediate. The client trusts only
        // root A and the root A intermediate for the same key.
        final server = await startServer(
          certificatePem: certificate,
          privateKeyPem: key,
          intermediatesPem: issuerIntermediateByRootBPem,
        );

        final assignments = await fetch(server, profile: issuerProfile);

        expect(assignments.flags['flag']?.variationValue, true);
        expect(server.requestBytes, hasLength(1));
      });
    }

    test('rejects a leaf from an interception root', () async {
      final server = await startServer(
        certificatePem: interceptionLeafCertificatePem,
        privateKeyPem: issuerLeaf1PrivateKeyPem,
      );

      await expectLater(
        fetch(server, profile: issuerProfile),
        throwsA(failedWith<HandshakeException>()),
      );
      await server.connectionsClosed;
      expect(server.requestBytes.where((bytes) => bytes.isNotEmpty), isEmpty);
    });

    test('does not use the platform trust store or the test context', () async {
      // The context trusts the leaf pinning CA, but issuer pinning ignores it.
      final server = await startServer(
        certificatePem: leafBRsaCertificatePem,
        privateKeyPem: leafBRsaPrivateKeyPem,
      );

      await expectLater(
        fetch(server, profile: issuerProfile, context: trustingTestCa()),
        throwsA(failedWith<HandshakeException>()),
      );
    });

    test('requires the root A intermediate to reach root A', () async {
      final server = await startServer(
        certificatePem: issuerLeaf1CertificatePem,
        privateKeyPem: issuerLeaf1PrivateKeyPem,
        intermediatesPem: issuerIntermediateByRootBPem,
      );
      // Leaf A only satisfies the minimum pin count.
      final rootAOnly = TlsPinningProfile.issuer(
        name: 'test',
        hosts: const {'localhost'},
        spkiSha256Pins: {
          issuerRootASpkiPin,
          spkiPin(
            subjectPublicKeyInfoFromCertificate(
              derFromPem(leafAEcCertificatePem),
            ),
          ),
        },
        issuerCertificates: const [issuerRootAPem, leafAEcCertificatePem],
      );

      await expectLater(
        fetch(server, profile: rootAOnly),
        throwsA(failedWith<HandshakeException>()),
      );
    });
  });

  test('rejects a request host outside the profile', () async {
    final server = await startServer(
      certificatePem: leafBRsaCertificatePem,
      privateKeyPem: leafBRsaPrivateKeyPem,
    );
    final endpoint = Uri.parse(
      'https://127.0.0.1:${server.port}/precompute-assignments',
    );
    final client = createTlsPinningHttpClient(
      TlsPinningPolicy.forEndpoint(
        const TlsPinningProfile(
          name: 'test',
          hosts: {'localhost'},
          spkiSha256Pins: {leafAEcSpkiPin, leafBRsaSpkiPin},
        ),
        Uri.parse('https://localhost/'),
      ),
      context: trustingTestCa(),
    );
    addTearDown(client.close);

    await expectLater(
      client.post(endpoint),
      throwsA(isA<TlsPinningException>()),
    );
    expect(server.handshakes, 0);
  });

  test('rejects proxies before connecting to them', () async {
    final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    var proxyConnections = 0;
    proxy.listen((socket) {
      proxyConnections++;
      socket.destroy();
    });
    addTearDown(proxy.close);

    await HttpOverrides.runZoned(() async {
      final client = createTlsPinningHttpClient(
        TlsPinningPolicy.forEndpoint(
          const TlsPinningProfile(
            name: 'test',
            hosts: {'localhost'},
            spkiSha256Pins: {leafAEcSpkiPin, leafBRsaSpkiPin},
          ),
          Uri.parse('https://localhost/'),
        ),
        context: trustingTestCa(),
      );
      addTearDown(client.close);

      await expectLater(
        client.post(Uri.parse('https://localhost:1/precompute-assignments')),
        throwsA(isA<TlsPinningException>()),
      );
    }, findProxyFromEnvironment: (_, _) => 'PROXY 127.0.0.1:${proxy.port}');
    expect(proxyConnections, 0);
  });
}

/// Minimal HTTPS/1.1 server that records the bytes of each connection.
final class _TlsServer {
  final SecureServerSocket _socket;
  final String _responseBody;
  final List<List<int>> requestBytes = [];
  final List<Future<void>> _connections = [];
  int handshakes = 0;

  _TlsServer._(this._socket, this._responseBody);

  static Future<_TlsServer> start(
    SecurityContext context,
    String responseBody,
  ) async {
    final socket = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    final server = _TlsServer._(socket, responseBody);
    socket.listen(
      server._accept,
      // Handshakes that the client aborts are reported here.
      onError: (Object _) {},
    );
    return server;
  }

  int get port => _socket.port;

  /// Completes when every accepted connection has closed.
  Future<void> get connectionsClosed => Future.wait(_connections);

  void _accept(SecureSocket socket) {
    handshakes++;
    final bytes = <int>[];
    requestBytes.add(bytes);
    final done = Completer<void>();
    _connections.add(done.future);
    socket.listen(
      (data) {
        bytes.addAll(data);
        if (_isCompleteRequest(bytes)) {
          final body = utf8.encode(_responseBody);
          socket
            ..write(
              'HTTP/1.1 200 OK\r\n'
              'Content-Type: application/json\r\n'
              'Content-Length: ${body.length}\r\n'
              'Connection: close\r\n\r\n',
            )
            ..add(body);
          unawaited(socket.close());
        }
      },
      onError: (Object _) {},
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
    );
  }

  static bool _isCompleteRequest(List<int> bytes) {
    final text = latin1.decode(bytes);
    final headerEnd = text.indexOf('\r\n\r\n');
    if (headerEnd < 0) return false;
    final match = RegExp(
      r'^content-length:\s*(\d+)\s*$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text.substring(0, headerEnd));
    final length = int.parse(match?.group(1) ?? '0');
    return bytes.length >= headerEnd + 4 + length;
  }

  Future<void> close() => _socket.close();
}
