// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:meta/meta.dart';

import 'flags_error.dart';
import 'response_protection.dart';

/// Creates an SDK-owned HTTP client that enforces [policy] on each connection.
http.Client createTlsPinningClient(TlsPinningPolicy policy) =>
    createTlsPinningHttpClient(policy);

/// Creates a pinning HTTP client for [policy].
///
/// [HttpClient.connectionFactory] opens each connection with a normally
/// validated TLS handshake for the exact request host, and only then returns
/// the socket to [HttpClient]:
///
/// - For [TlsPinTarget.leaf], the factory validates with [context] (or the
///   platform trust store) and checks the leaf certificate SPKI against
///   [policy]. On a mismatch, it destroys the socket before [HttpClient]
///   writes request headers or body.
/// - For [TlsPinTarget.issuer], the factory validates with a trust store that
///   contains only [TlsPinningPolicy.issuerCertificates]. [context] is not
///   used. Dart exposes only the leaf certificate of a connection, so the
///   restricted trust store enforces the issuer pins.
///
/// Throws [FlagsException] when the issuer certificates cannot be loaded.
@visibleForTesting
http.Client createTlsPinningHttpClient(
  TlsPinningPolicy policy, {
  SecurityContext? context,
}) {
  final connectionContext = switch (policy.target) {
    TlsPinTarget.leaf => context,
    TlsPinTarget.issuer => _issuerTrustStore(policy),
  };
  final client = HttpClient(context: connectionContext)
    ..connectionFactory = (uri, proxyHost, proxyPort) =>
        _connect(policy, connectionContext, uri, proxyHost);
  return IOClient(client);
}

SecurityContext _issuerTrustStore(TlsPinningPolicy policy) {
  final context = SecurityContext(withTrustedRoots: false);
  try {
    for (final pem in policy.issuerCertificates) {
      context.setTrustedCertificatesBytes(utf8.encode(pem));
    }
  } on TlsException catch (error) {
    throw FlagsException.invalidConfiguration(
      'Failed to load TLS pinning issuer certificates.',
      cause: error,
    );
  }
  return context;
}

Future<ConnectionTask<Socket>> _connect(
  TlsPinningPolicy policy,
  SecurityContext? context,
  Uri uri,
  String? proxyHost,
) async {
  // A proxy tunnel would run the TLS handshake outside this factory.
  if (proxyHost != null) {
    throw const TlsPinningException(
      'Proxies are not supported for assignment requests that require TLS '
      'pinning.',
    );
  }
  if (!uri.isScheme('https') || !policy.hosts.contains(uri.host)) {
    throw TlsPinningException(
      'The TLS pinning profile does not cover ${uri.scheme}://${uri.host}.',
    );
  }

  // No onBadCertificate callback: a certificate that fails normal
  // validation fails the handshake.
  final task = await SecureSocket.startConnect(
    uri.host,
    uri.port,
    context: context,
  );
  if (policy.target == TlsPinTarget.issuer) {
    return task;
  }
  final socket = task.socket.then((socket) {
    final certificate = socket.peerCertificate;
    if (certificate == null || !policy.matchesCertificate(certificate.der)) {
      socket.destroy();
      throw TlsPinningException(
        'The server certificate for ${uri.host} does not match the TLS '
        'pinning profile.',
      );
    }
    return socket;
  });
  return ConnectionTask.fromSocket(socket, task.cancel);
}
