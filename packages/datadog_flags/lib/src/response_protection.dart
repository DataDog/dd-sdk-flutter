// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'assignment_transport.dart';
import 'datadog_tls_certificates.dart';
import 'datadog_flags_config.dart';
import 'flags_configuration.dart';
import 'flags_error.dart';
import 'flags_log.dart';

/// Enforcement mode for [ResponseProtection].
enum ResponseProtectionMode {
  /// Reject new assignment data unless the selected protection method
  /// succeeds.
  ///
  /// Stored assignments are restored only when the same protection policy
  /// fetched them.
  required,
}

/// Local policy that protects precompute assignment responses.
///
/// The application selects the method. A server response cannot change the
/// method, the endpoint, or the trusted keys.
///
/// Protection applies only to the precompute assignment request. Exposure and
/// evaluation telemetry use the ordinary HTTP client.
@immutable
abstract final class ResponseProtection {
  /// Enforcement mode for this policy.
  final ResponseProtectionMode mode;

  const ResponseProtection._(this.mode);

  /// Requires normal TLS validation plus a match against the public key pins
  /// in [profile] on each assignment connection.
  ///
  /// TLS pinning is available on Dart IO platforms (Android, iOS, and
  /// desktop). On web, assignment fetches fail with an unsupported
  /// configuration error before the SDK sends a request.
  ///
  /// The SDK reports an invalid policy as a client initialization error and
  /// logs a warning. It does not throw from this constructor.
  const factory ResponseProtection.tlsPinning({
    required ResponseProtectionMode mode,
    required TlsPinningProfile profile,
  }) = TlsPinningResponseProtection;
}

/// [ResponseProtection] that pins the TLS server public key of the assignment
/// endpoint.
@immutable
final class TlsPinningResponseProtection extends ResponseProtection {
  /// Hosts and public key pins that the assignment connection must match.
  final TlsPinningProfile profile;

  /// Creates a TLS pinning policy. Prefer [ResponseProtection.tlsPinning].
  const TlsPinningResponseProtection({
    required ResponseProtectionMode mode,
    required this.profile,
  }) : super._(mode);
}

/// Certificate in the server chain that [TlsPinningProfile] pins.
enum TlsPinTarget {
  /// The server's leaf certificate.
  ///
  /// The SDK accepts a connection after normal TLS validation when the leaf
  /// certificate SPKI matches a pin. A leaf key change requires a profile
  /// that already contains the new pin.
  leaf,

  /// The CA certificates that issue the server certificate.
  ///
  /// The assignment connection trusts only
  /// [TlsPinningProfile.issuerCertificates], instead of the platform trust
  /// store. A connection succeeds when the server chain validates to one of
  /// these certificates. Leaf keys can change on renewal without a profile
  /// update.
  issuer,
}

/// Versioned TLS pinning policy for an assignment endpoint.
///
/// A profile contains exact host names and base64-encoded SHA-256 digests of
/// DER-encoded `SubjectPublicKeyInfo` (SPKI) structures. [target] selects the
/// certificate that the pins apply to. A connection is accepted when any pin
/// matches, so a profile with the current key and the next key supports a key
/// rotation without an application update.
///
/// A profile requires at least two distinct pins. Host names match exactly;
/// the SDK does not apply wildcard or suffix matching.
@immutable
final class TlsPinningProfile {
  /// Datadog staging profile for `protected.ff-cdn.datad0g.com`.
  ///
  /// This profile pins the Certainly CAs that issue the endpoint's Fastly
  /// managed certificates. Fastly renews and rekeys the leaf certificates, so
  /// the profile pins issuers, not leaves.
  ///
  /// Assignment requests go to
  /// `https://protected.ff-cdn.datad0g.com/precompute-assignments`, whatever
  /// the configured [DatadogFlagsSite].
  // The endpoint is pending provisioning and live validation
  // (ddoghq/terraform-config PR 62220).
  static const datadogStagingV1 = TlsPinningProfile.issuer(
    name: 'datadogStagingV1',
    hosts: {'protected.ff-cdn.datad0g.com'},
    spkiSha256Pins: {
      // Certainly Root R1.
      'P5Pz/PedIl0hPu9qSj9Yhc+E/j16ejwRVTUXaIwOIQA=',
      // Certainly Intermediate R1.
      'oW7smChMJRcnzTObF7K+HzInReAPTxB/L1h6eZTmw9Q=',
      // Certainly Root E1.
      'HvZGJdqi5dQz10Sa4xogDRAl4AEqj+z6cJMvi1mbdd0=',
      // Certainly Intermediate E1.
      'XkxTESlVMF59ZsGRFSBQJyCYjYJYNYkLwv/sqaDnMJA=',
    },
    issuerCertificates: [
      certainlyRootR1Pem,
      certainlyIntermediateR1Pem,
      certainlyRootE1Pem,
      certainlyIntermediateE1Pem,
    ],
  );

  /// Minimum number of distinct pins in a profile.
  static const minimumPinCount = 2;

  /// Name that identifies this profile and its version.
  final String name;

  /// Exact host names that this profile covers.
  ///
  /// With one host and no [DatadogFlagsConfiguration.customFlagsEndpoint],
  /// assignment requests go to `https://<host>/precompute-assignments` and
  /// keep the automatic capability header of Datadog endpoints. A profile with
  /// more than one host requires a
  /// [DatadogFlagsConfiguration.customFlagsEndpoint] on one of the hosts.
  /// A custom endpoint must always use a host in this set.
  final Set<String> hosts;

  /// Base64-encoded SHA-256 digests of DER-encoded SPKI for [target].
  final Set<String> spkiSha256Pins;

  /// Certificate in the server chain that [spkiSha256Pins] apply to.
  final TlsPinTarget target;

  /// PEM-encoded CA certificates for [TlsPinTarget.issuer].
  ///
  /// The SPKI pin of each certificate must be in [spkiSha256Pins], and each
  /// pin must belong to one of these certificates. Empty for
  /// [TlsPinTarget.leaf].
  final List<String> issuerCertificates;

  /// Creates a custom leaf pinning profile for a custom assignment endpoint.
  ///
  /// See [hosts] for endpoint selection.
  const TlsPinningProfile({
    required this.name,
    required this.hosts,
    required this.spkiSha256Pins,
  }) : target = TlsPinTarget.leaf,
       issuerCertificates = const [];

  /// Creates an issuer pinning profile.
  ///
  /// [issuerCertificates] become the only trusted certificates for the
  /// assignment connection. Include each CA certificate that the server chain
  /// must reach, including cross-signed intermediates that link the served
  /// chain to a pinned root.
  const TlsPinningProfile.issuer({
    required this.name,
    required this.hosts,
    required this.spkiSha256Pins,
    required this.issuerCertificates,
  }) : target = TlsPinTarget.issuer;
}

/// Error raised when an assignment connection cannot satisfy a TLS pinning
/// policy.
@internal
final class TlsPinningException implements Exception {
  final String message;

  const TlsPinningException(this.message);

  @override
  String toString() => 'TlsPinningException: $message';
}

/// Validated TLS pinning policy used by the assignment transport.
@internal
@immutable
final class TlsPinningPolicy {
  /// Lowercase host names that the connection can reach.
  final Set<String> hosts;

  /// Canonical base64 SHA-256 SPKI pins.
  final Set<String> pins;

  /// Certificate in the server chain that [pins] apply to.
  final TlsPinTarget target;

  /// PEM-encoded trusted certificates for [TlsPinTarget.issuer].
  final List<String> issuerCertificates;

  const TlsPinningPolicy._({
    required this.hosts,
    required this.pins,
    required this.target,
    required this.issuerCertificates,
  });

  /// Validates [profile] for [endpoint].
  ///
  /// Throws [FlagsException] with [FlagsErrorType.invalidConfiguration] when
  /// the profile or endpoint cannot be enforced.
  factory TlsPinningPolicy.forEndpoint(
    TlsPinningProfile profile,
    Uri endpoint,
  ) {
    FlagsException invalid(String message) =>
        FlagsException.invalidConfiguration(
          'Invalid TLS pinning profile "${profile.name}": $message',
        );

    if (profile.hosts.isEmpty) {
      throw invalid('the profile must contain at least one host.');
    }
    final hosts = <String>{};
    for (final host in profile.hosts) {
      final normalized = host.toLowerCase();
      if (normalized.isEmpty ||
          normalized.contains('*') ||
          Uri.tryParse('https://$normalized')?.host != normalized) {
        throw invalid('"$host" is not an exact host name.');
      }
      hosts.add(normalized);
    }

    final pins = <String>{};
    for (final pin in profile.spkiSha256Pins) {
      final Uint8List digest;
      try {
        digest = base64.decode(pin);
      } on FormatException {
        throw invalid('"$pin" is not base64.');
      }
      if (digest.length != 32) {
        throw invalid('"$pin" is not a SHA-256 digest.');
      }
      pins.add(base64.encode(digest));
    }
    if (pins.length < TlsPinningProfile.minimumPinCount) {
      throw invalid(
        'the profile must contain at least '
        '${TlsPinningProfile.minimumPinCount} distinct pins.',
      );
    }

    switch (profile.target) {
      case TlsPinTarget.leaf:
        if (profile.issuerCertificates.isNotEmpty) {
          throw invalid('leaf pinning does not use issuer certificates.');
        }
      case TlsPinTarget.issuer:
        if (profile.issuerCertificates.isEmpty) {
          throw invalid('issuer pinning requires issuer certificates.');
        }
        final certificatePins = <String>{};
        for (final (index, pem) in profile.issuerCertificates.indexed) {
          final String pin;
          try {
            pin = spkiPin(subjectPublicKeyInfoFromCertificate(derFromPem(pem)));
          } on FormatException {
            throw invalid(
              'issuer certificate $index is not a PEM certificate.',
            );
          }
          if (!pins.contains(pin)) {
            throw invalid('issuer certificate $index ($pin) is not pinned.');
          }
          certificatePins.add(pin);
        }
        final missing = pins.difference(certificatePins);
        if (missing.isNotEmpty) {
          throw invalid(
            'pins ${missing.join(', ')} have no issuer certificate.',
          );
        }
    }

    if (!endpoint.isScheme('https')) {
      throw invalid('the assignment endpoint $endpoint must use HTTPS.');
    }
    if (!hosts.contains(endpoint.host)) {
      throw invalid(
        'the assignment endpoint host "${endpoint.host}" is not in the profile.',
      );
    }
    return TlsPinningPolicy._(
      hosts: hosts,
      pins: pins,
      target: profile.target,
      issuerCertificates: List.unmodifiable(profile.issuerCertificates),
    );
  }

  /// Whether the SPKI of the DER-encoded leaf [certificate] matches a pin.
  bool matchesCertificate(Uint8List certificate) {
    final Uint8List spki;
    try {
      spki = subjectPublicKeyInfoFromCertificate(certificate);
    } on FormatException {
      return false;
    }
    return pins.contains(spkiPin(spki));
  }
}

/// Assignment transport selected by [DatadogFlagsConfiguration.responseProtection].
@internal
final class AssignmentProtection {
  /// Identifier stored with assignments that this policy fetched.
  final String policyId;

  /// SDK-owned HTTP client that enforces the policy.
  final http.Client? client;

  /// Configuration error that blocks every assignment fetch.
  final FlagsException? error;

  AssignmentProtection({required this.policyId, this.client, this.error});

  /// Returns the protected transport for [configuration], or `null` when
  /// [DatadogFlagsConfiguration.responseProtection] is not set.
  ///
  /// This method does not throw. Configuration errors are logged and returned
  /// in [error].
  static AssignmentProtection? resolve({
    required DatadogFlagsConfiguration configuration,
    required Uri endpoint,
    FlagsLogger logger = const FlagsLogger(),
  }) {
    final protection = configuration.responseProtection;
    if (protection is! TlsPinningResponseProtection) {
      return null;
    }

    final profile = protection.profile;
    final policyId = _policyId(protection, endpoint);
    try {
      if (configuration.httpClient != null) {
        throw FlagsException.invalidConfiguration(
          'Required TLS pinning cannot be enforced through a custom httpClient. '
          'Remove DatadogFlagsConfiguration.httpClient to use TLS pinning.',
        );
      }
      if (configuration.customFlagsEndpoint == null &&
          profile.hosts.length > 1) {
        throw FlagsException.invalidConfiguration(
          'TLS pinning profile "${profile.name}" has more than one host. '
          'Set DatadogFlagsConfiguration.customFlagsEndpoint to one of them.',
        );
      }
      final policy = TlsPinningPolicy.forEndpoint(profile, endpoint);
      return AssignmentProtection(
        policyId: policyId,
        client: createTlsPinningClient(policy),
      );
    } on FlagsException catch (error) {
      logger.warning(
        'Flag assignments are disabled: ${error.message}',
        error: error,
      );
      return AssignmentProtection(policyId: policyId, error: error);
    }
  }

  /// Releases the SDK-owned protected client.
  void close() => client?.close();

  static String _policyId(
    TlsPinningResponseProtection protection,
    Uri endpoint,
  ) {
    final profile = protection.profile;
    final canonical = jsonEncode({
      'method': 'tlsPinning',
      'mode': protection.mode.name,
      'profile': profile.name,
      'hosts': [for (final host in profile.hosts) host.toLowerCase()]..sort(),
      'pins': profile.spkiSha256Pins.toList()..sort(),
      'target': profile.target.name,
      'issuerCertificates': [
        for (final pem in profile.issuerCertificates)
          sha256.convert(utf8.encode(pem)).toString(),
      ],
      'endpoint': endpoint.toString(),
    });
    return 'tlsPinning:${sha256.convert(utf8.encode(canonical))}';
  }
}

/// Returns the base64 SHA-256 digest of a DER-encoded [spki].
@internal
String spkiPin(Uint8List spki) => base64.encode(sha256.convert(spki).bytes);

/// Decodes one PEM `CERTIFICATE` block.
///
/// Throws [FormatException] when [pem] does not contain exactly one
/// certificate.
@internal
Uint8List derFromPem(String pem) {
  final match = RegExp(
    r'^\s*-----BEGIN CERTIFICATE-----([A-Za-z0-9+/=\s]+)-----END CERTIFICATE-----\s*$',
  ).firstMatch(pem);
  if (match == null) {
    throw const FormatException('Expected one PEM certificate');
  }
  return base64.decode(match.group(1)!.replaceAll(RegExp(r'\s'), ''));
}

/// Returns the DER-encoded `SubjectPublicKeyInfo` of an X.509 [certificate].
///
/// Throws [FormatException] when [certificate] is not a DER-encoded X.509
/// certificate.
@internal
Uint8List subjectPublicKeyInfoFromCertificate(Uint8List certificate) {
  const sequence = 0x30;
  const integer = 0x02;
  const bitString = 0x03;
  const explicitVersion = 0xa0;

  final outer = _DerReader(certificate, 0, certificate.length);
  final certificateElement = outer.read(sequence);
  outer.expectEnd();

  final certificateFields = certificateElement.contents();
  final tbsCertificate = certificateFields.read(sequence).contents();
  if (tbsCertificate.nextTag == explicitVersion) {
    tbsCertificate.read(explicitVersion);
  }
  tbsCertificate
    ..read(integer) // serialNumber
    ..read(sequence) // signature
    ..read(sequence) // issuer
    ..read(sequence) // validity
    ..read(sequence); // subject
  final spki = tbsCertificate.read(sequence);

  final spkiFields = spki.contents();
  spkiFields
    ..read(sequence) // algorithm
    ..read(bitString) // subjectPublicKey
    ..expectEnd();

  return Uint8List.sublistView(certificate, spki.start, spki.end);
}

/// One DER tag-length-value element.
final class _DerElement {
  final Uint8List bytes;
  final int start;
  final int contentStart;
  final int end;

  const _DerElement(this.bytes, this.start, this.contentStart, this.end);

  _DerReader contents() => _DerReader(bytes, contentStart, end);
}

/// Sequential reader for single-byte-tag DER elements.
final class _DerReader {
  final Uint8List _bytes;
  final int _end;
  int _offset;

  _DerReader(this._bytes, this._offset, this._end);

  int? get nextTag => _offset < _end ? _bytes[_offset] : null;

  _DerElement read(int tag) {
    final start = _offset;
    if (nextTag != tag) {
      throw FormatException(
        'Expected DER tag 0x${tag.toRadixString(16)}',
        _bytes,
        start,
      );
    }
    var offset = start + 1;
    if (offset >= _end) {
      throw FormatException('Truncated DER length', _bytes, offset);
    }
    final first = _bytes[offset++];
    var length = first;
    if (first & 0x80 != 0) {
      final count = first & 0x7f;
      // DER forbids the indefinite form. Four bytes covers any certificate.
      if (count == 0 || count > 4 || offset + count > _end) {
        throw FormatException('Unsupported DER length', _bytes, offset - 1);
      }
      length = 0;
      for (var i = 0; i < count; i++) {
        length = (length << 8) | _bytes[offset++];
      }
      if (length < 0x80) {
        throw FormatException('Non-minimal DER length', _bytes, start + 1);
      }
    }
    final contentEnd = offset + length;
    if (contentEnd > _end) {
      throw FormatException('Truncated DER element', _bytes, start);
    }
    _offset = contentEnd;
    return _DerElement(_bytes, start, offset, contentEnd);
  }

  void expectEnd() {
    if (_offset != _end) {
      throw FormatException('Unexpected DER data', _bytes, _offset);
    }
  }
}
