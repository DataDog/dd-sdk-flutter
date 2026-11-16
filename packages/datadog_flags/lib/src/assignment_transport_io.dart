// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:meta/meta.dart';

import 'response_protection.dart';

/// Creates an SDK-owned HTTP client that enforces [policy] on each connection.
http.Client createTlsPinningClient(TlsPinningPolicy policy) =>
    createTlsPinningHttpClient(policy);

/// Creates a pinning HTTP client that validates certificates with [context].
///
/// [HttpClient.connectionFactory] opens each connection. The factory completes
/// a normally validated TLS handshake for the exact request host, checks the
/// leaf certificate SPKI against [policy], and only then returns the socket to
/// [HttpClient]. On a mismatch, the factory destroys the socket before
/// [HttpClient] writes request headers or body.
@visibleForTesting
http.Client createTlsPinningHttpClient(
  TlsPinningPolicy policy, {
  SecurityContext? context,
}) {
  final client = HttpClient(context: context)
    ..connectionFactory = (uri, proxyHost, proxyPort) =>
        _connect(policy, context, uri, proxyHost);
  return IOClient(client);
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
