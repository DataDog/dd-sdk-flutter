// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';

import '../../datadog_flutter_plugin.dart';
import '../../datadog_internal.dart';

// The resulting baggage-string should contain 64 list-members or less (https://www.w3.org/TR/baggage/#limits)
const _maxBaggageMembers = 64;

// The resulting baggage-string should be of size 8192 bytes or less (https://www.w3.org/TR/baggage/#limits)
const _maxBaggageBytes = 8192;

// The keys must follow RFC 7230 token grammar (https://datatracker.ietf.org/doc/html/rfc7230#section-3.2.6)
final RegExp _baggageTokenRegExp = RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

class W3CHeadersBaggageKeys {
  static const sessionId = 'session.id';
  static const accountId = 'account.id';
  static const userId = 'user.id';
}

// Safe char codes for baggage headers. ASCII codes except for
bool _isSafeCharCode(int charCode) {
  if (charCode < 0x21 || charCode > 0x7e) return false;
  switch (charCode) {
    case 0x22: // "
    case 0x2c: // ,
    case 0x3b: // ;
    case 0x5c: // \
    case 0x25: // %
      return false;
  }
  return true;
}

String _encodeBaggageValue(String value) {
  value = _percentDecode(value);
  final sb = StringBuffer();
  for (final rune in value.runes) {
    if (_isSafeCharCode(rune)) {
      sb.writeCharCode(rune);
    } else {
      final uft8Bytes = utf8.encode(String.fromCharCode(rune));
      final str = uft8Bytes
          .map((i) => '%${i.toRadixString(16).toUpperCase().padLeft(2, '0')}')
          .join();
      sb.write(str);
    }
  }
  return sb.toString();
}

final _escapeRE = RegExp(r'(?:%[\da-fA-F]{2})+');
String _percentDecode(String value) {
  // This looks for percent encoded values and replaces them with their decoded
  // values, leaving stand alone percents.
  return value.replaceAllMapped(_escapeRE, (m) => Uri.decodeComponent(m[0]!));
}

Map<String, String> _deconstructBaggageHeader(
  String baggageHeader,
  InternalLogger logger,
) {
  Map<String, String> baggageValueMap = Map.fromEntries(
    baggageHeader.split(',').map((v) {
      v = v.trim();
      if (v.isEmpty) return null;

      final firstEqualsIndex = v.indexOf('=');
      if (firstEqualsIndex < 0) {
        logger.warn('Invalid baggage header entry "$v". Key missing value.');
        return v;
      }

      final key = v.substring(0, firstEqualsIndex).trim();
      if (!_baggageTokenRegExp.hasMatch(key)) {
        logger.warn(
          'Invalid baggage header entry "$v". Key not compliant to RFC 7230 grammar.',
        );
        return v;
      }

      final rawValue = v.substring(firstEqualsIndex + 1).trim();

      final rawProperties = rawValue.split(';');
      final properties = <String>[rawProperties.first];
      if (rawProperties.length > 1) {
        for (var rawProperty in rawProperties.sublist(1)) {
          final firstEqualsIndex = rawProperty.indexOf('=');
          if (firstEqualsIndex < 0) {
            if (!_baggageTokenRegExp.hasMatch(rawProperty)) {
              logger.warn(
                'Invalid baggage header entry "$rawProperty". Key not compliant to RFC 7230 grammar.',
              );
            }
            properties.add(rawProperty);
          } else {
            final propertyKey = rawProperty.substring(0, firstEqualsIndex);
            final propertyValue =
                rawProperty.substring(firstEqualsIndex + 1).trim();
            if (!_baggageTokenRegExp.hasMatch(propertyKey)) {
              logger.warn(
                'Invalid baggage header entry "$rawProperty". Key not compliant to RFC 7230 grammar.',
              );
            }
            properties.add('$propertyKey=$propertyValue');
          }
        }
      }
      final value = properties.join(';');

      return MapEntry(key, value);
    }).whereType<MapEntry<String, String>>(),
  );
  return baggageValueMap;
}

/// This assumes validation of the baggage properties and values has already
/// occured through [_deconstructBaggageHeader] and new members have been
/// properly encoded with [_encodeBaggageValue].
String _constructBaggageHeader(
  Map<String, String> entries,
  InternalLogger logger,
) {
  if (entries.length > _maxBaggageMembers) {
    logger.warn(
      'Baggage header has too many members: ${entries.length} > $_maxBaggageMembers - entries may be dropped',
    );
  }

  final header = entries.entries.map((e) => '${e.key}=${e.value}').join(',');
  // All characters should already be in the ASCII space so length and bytes should be the same.
  if (header.length > _maxBaggageBytes) {
    logger.warn(
      'Baggage header is too large: ${header.length} > $_maxBaggageBytes - entries may be dropped',
    );
  }

  return header;
}

String mergeW3CBaggageHeader(TracingContext context, String? baggageHeader) {
  final logger = DatadogSdk.instance.internalLogger;
  baggageHeader ??= '';

  Map<String, String> baggageValueMap = _deconstructBaggageHeader(
    baggageHeader,
    logger,
  );

  if (context.rumSessionId case final sessionId?) {
    baggageValueMap[W3CHeadersBaggageKeys.sessionId] = _encodeBaggageValue(
      sessionId,
    );
  }

  if (context.userId case final userId?) {
    baggageValueMap[W3CHeadersBaggageKeys.userId] = _encodeBaggageValue(userId);
  }

  if (context.accountId case final accountId?) {
    baggageValueMap[W3CHeadersBaggageKeys.accountId] = _encodeBaggageValue(
      accountId,
    );
  }

  return _constructBaggageHeader(baggageValueMap, logger);
}
