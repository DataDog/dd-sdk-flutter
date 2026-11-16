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

/// Versioned TLS pinning policy for an assignment endpoint.
///
/// A profile contains exact host names and base64-encoded SHA-256 digests of
/// DER-encoded `SubjectPublicKeyInfo` (SPKI) structures. The SDK compares the
/// pins with the SPKI of the server's leaf certificate after normal TLS
/// validation succeeds. A connection is accepted when any pin matches, so a
/// profile with the current key and the next key supports a key rotation
/// without an application update.
///
/// A profile requires at least two distinct pins. Host names match exactly;
/// the SDK does not apply wildcard or suffix matching.
@immutable
final class TlsPinningProfile {
  /// Proposed Datadog staging profile.
  ///
  /// **Unverified placeholder.** The pins in this profile are not the public
  /// keys of any Datadog certificate. They are placeholder digests that never
  /// match a server, so every assignment request that uses this profile fails.
  /// The host name is also a placeholder until a dedicated staging host name is
  /// provisioned. Replace both with a reviewed pin policy before activation.
  static const datadogStagingV1 = TlsPinningProfile._(
    name: 'datadogStagingV1',
    hosts: {'preview.ff-cdn.datad0g.com'},
    spkiSha256Pins: {
      // SHA-256 of "datadog_flags unverified placeholder pin datadogStagingV1-a".
      'xB1ueNJyEgtwbIPFUkgvHd6RiriujFIR15GNtYN4qLk=',
      // SHA-256 of "datadog_flags unverified placeholder pin datadogStagingV1-b".
      'oN9O+mYi8ngW8iJms8E5+hy2OgMLxo3Y6o/6YI49z1g=',
    },
    isPlaceholder: true,
  );

  /// Minimum number of distinct pins in a profile.
  static const minimumPinCount = 2;

  /// Name that identifies this profile and its version.
  final String name;

  /// Exact host names that this profile covers.
  final Set<String> hosts;

  /// Base64-encoded SHA-256 digests of DER-encoded leaf certificate SPKI.
  final Set<String> spkiSha256Pins;

  final bool _isPlaceholder;

  /// Creates a custom pinning profile for a custom assignment endpoint.
  ///
  /// Use [DatadogFlagsConfiguration.customFlagsEndpoint] to select an endpoint
  /// whose host is in [hosts].
  const TlsPinningProfile({
    required this.name,
    required this.hosts,
    required this.spkiSha256Pins,
  }) : _isPlaceholder = false;

  const TlsPinningProfile._({
    required this.name,
    required this.hosts,
    required this.spkiSha256Pins,
    required bool isPlaceholder,
  }) : _isPlaceholder = isPlaceholder;
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

  const TlsPinningPolicy._({required this.hosts, required this.pins});

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

    if (!endpoint.isScheme('https')) {
      throw invalid('the assignment endpoint $endpoint must use HTTPS.');
    }
    if (!hosts.contains(endpoint.host)) {
      throw invalid(
        'the assignment endpoint host "${endpoint.host}" is not in the profile.',
      );
    }
    return TlsPinningPolicy._(hosts: hosts, pins: pins);
  }

  /// Whether the SPKI of the DER-encoded [certificate] matches a pin.
  bool matchesCertificate(Uint8List certificate) {
    final Uint8List spki;
    try {
      spki = subjectPublicKeyInfoFromCertificate(certificate);
    } on FormatException {
      return false;
    }
    return pins.contains(base64.encode(sha256.convert(spki).bytes));
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
      final policy = TlsPinningPolicy.forEndpoint(profile, endpoint);
      if (profile._isPlaceholder) {
        logger.warning(
          'TLS pinning profile "${profile.name}" contains unverified '
          'placeholder pins. Assignment requests fail until it is replaced.',
        );
      }
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
      'endpoint': endpoint.toString(),
    });
    return 'tlsPinning:${sha256.convert(utf8.encode(canonical))}';
  }
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
