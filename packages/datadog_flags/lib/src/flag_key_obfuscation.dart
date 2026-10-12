// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'flag_key_obfuscation.g.dart';

enum FlagsCapability {
  assignmentEncodingFlagKey256V1('assignment-encoding-flag-key-256-v1');

  final String wireName;

  const FlagsCapability(this.wireName);
}

const supportedFlagsCapabilities = [
  FlagsCapability.assignmentEncodingFlagKey256V1,
];

/// Encoding metadata that belongs to one assignment snapshot.
@immutable
@JsonSerializable(constructor: '_')
final class FlagKeyObfuscation {
  static const supportedScheme = 'flag-key-sha256-v1';
  static final _domain = utf8.encode('datadog.feature-flags.flag-key.v1\u0000');

  @JsonKey(fromJson: _schemeFromJson)
  final String scheme;
  @JsonKey(fromJson: _saltFromJson)
  final String salt;
  final _lookupKeys = <String, String>{};
  static const _lookupCacheLimit = 1024;

  FlagKeyObfuscation._(this.scheme, this.salt);

  factory FlagKeyObfuscation.fromJson(Map<String, Object?> json) =>
      _$FlagKeyObfuscationFromJson(json);

  /// Validates the wire fields, including explicitly null fields.
  static FlagKeyObfuscation? fromSnapshot(Map<String, Object?> json) {
    final obfuscated = json['obfuscated'];
    if ((!json.containsKey('obfuscated') || obfuscated == false) &&
        !json.containsKey('obfuscation')) {
      return null;
    }
    final descriptor = json['obfuscation'];
    if (obfuscated != true || descriptor is! Map) {
      throw const FormatException('Invalid flag-key obfuscation metadata');
    }
    return FlagKeyObfuscation.fromJson(Map<String, Object?>.from(descriptor));
  }

  void validateKeys(Iterable<String> keys) {
    if (keys.any((key) => !_isLowercaseHex(key, 32))) {
      throw const FormatException(
        'Encoded flag keys must contain 64 lowercase hexadecimal characters',
      );
    }
  }

  Map<String, Object?> toJson() => _$FlagKeyObfuscationToJson(this);

  /// Returns null for malformed Unicode instead of hashing a replacement rune.
  String? encodeKey(String key) {
    final cached = _lookupKeys[key];
    if (cached != null) return cached;
    for (var index = 0; index < key.length; index++) {
      final unit = key.codeUnitAt(index);
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++index == key.length) return null;
        final next = key.codeUnitAt(index);
        if (next < 0xdc00 || next > 0xdfff) return null;
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        return null;
      }
    }
    final saltBytes = [
      for (var index = 0; index < salt.length; index += 2)
        int.parse(salt.substring(index, index + 2), radix: 16),
    ];
    final digest = sha256
        .convert([..._domain, ...saltBytes, ...utf8.encode(key)]).toString();
    if (_lookupKeys.length >= _lookupCacheLimit) _lookupKeys.clear();
    _lookupKeys[key] = digest;
    return digest;
  }
}

String _schemeFromJson(Object? value) {
  if (value != FlagKeyObfuscation.supportedScheme) {
    throw const FormatException('Unsupported flag-key obfuscation scheme');
  }
  return value as String;
}

String _saltFromJson(Object? value) {
  if (!_isLowercaseHex(value, 16)) {
    throw const FormatException(
      'Flag-key salt must contain 32 lowercase hexadecimal characters',
    );
  }
  return value as String;
}

bool _isLowercaseHex(Object? value, int bytes) =>
    value is String &&
    value.length == bytes * 2 &&
    value.codeUnits.every((unit) =>
        (unit >= 0x30 && unit <= 0x39) || (unit >= 0x61 && unit <= 0x66));
