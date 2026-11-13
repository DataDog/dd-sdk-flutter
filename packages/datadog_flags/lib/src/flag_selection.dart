// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:meta/meta.dart';

import 'flags_log.dart';

/// Selects the flags a client loads, by tag or by key pattern.
///
/// A flag is loaded when it has any of the [tags] or its key matches any of
/// the [keyPatterns]. Tags match exactly and case-sensitively. Key patterns
/// match the whole key case-sensitively; only `*` is special, and it matches
/// any run of characters, including none.
///
/// Leading and trailing Unicode `White_Space` characters are trimmed from
/// every value, empty values are dropped, and duplicates are removed. Limits
/// apply after this: each list accepts at most 31 values, and each tag and key
/// pattern is at most 200 UTF-8 bytes. A selection over a limit, or with an
/// unpaired UTF-16 surrogate, is not sent: the SDK logs an error and loads
/// every flag. When both lists are empty, every flag is loaded.
///
/// When the server applies the selection, flags outside it are not loaded, and
/// evaluating one returns the default value. When the server ignores the
/// selection, the full configuration loads and the SDK logs the reason.
@immutable
final class FlagSelection {
  /// Tags to select. A flag is selected when it has any of these tags.
  final List<String> tags;

  /// Whole-key patterns to select, where `*` matches any run of characters.
  final List<String> keyPatterns;

  /// Creates a flag selection.
  const FlagSelection({this.tags = const [], this.keyPatterns = const []});
}

const maxFlagSelectionValues = 31;
const maxFlagSelectionTagBytes = 200;
const maxFlagSelectionKeyPatternBytes = 200;

/// Reasons the SDK drops a selection, with the reason codes the server uses.
enum FlagSelectionError {
  malformedSelection(
    'malformed_selection',
    'flagSelection must be an object with optional tags and keyPatterns string arrays',
  ),
  tooManyValues(
    'too_many_values',
    'each list accepts at most $maxFlagSelectionValues values',
  ),
  invalidKeyPattern(
    'invalid_key_pattern',
    'each key pattern is at most $maxFlagSelectionKeyPatternBytes UTF-8 bytes',
  ),
  invalidTag(
    'invalid_tag',
    'each tag is at most $maxFlagSelectionTagBytes UTF-8 bytes',
  );

  final String reason;
  final String limit;

  const FlagSelectionError(this.reason, this.limit);
}

/// A canonical [selection], or the [error] it was dropped for. Both are null
/// when there is no selection to send.
typedef FlagSelectionResult = ({
  FlagSelection? selection,
  FlagSelectionError? error,
});

// The Unicode White_Space property, which the server trims. String.trim()
// differs: it also trims U+FEFF and does not trim U+0085.
const _whiteSpace = {
  0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x0020, 0x0085, 0x00A0, 0x1680, //
  0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008, //
  0x2009, 0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000,
};

/// Canonicalizes and validates [input] with the same rules as the server.
FlagSelectionResult canonicalizeFlagSelection(FlagSelection? input) {
  if (input == null) return (selection: null, error: null);
  if (!input.tags.every(_isWellFormed) ||
      !input.keyPatterns.every(_isWellFormed)) {
    return (selection: null, error: FlagSelectionError.malformedSelection);
  }

  final tags = _canonicalizeList(input.tags);
  final keyPatterns = _canonicalizeList(input.keyPatterns);
  final FlagSelectionError? error;
  if (tags.length > maxFlagSelectionValues ||
      keyPatterns.length > maxFlagSelectionValues) {
    error = FlagSelectionError.tooManyValues;
  } else if (keyPatterns.any(
    (pattern) => utf8.encode(pattern).length > maxFlagSelectionKeyPatternBytes,
  )) {
    error = FlagSelectionError.invalidKeyPattern;
  } else if (tags.any(
    (tag) => utf8.encode(tag).length > maxFlagSelectionTagBytes,
  )) {
    error = FlagSelectionError.invalidTag;
  } else {
    error = null;
  }
  if (error != null) return (selection: null, error: error);
  if (tags.isEmpty && keyPatterns.isEmpty) {
    return (selection: null, error: null);
  }
  return (
    selection: FlagSelection(
      tags: List.unmodifiable(tags),
      keyPatterns: List.unmodifiable(keyPatterns),
    ),
    error: null,
  );
}

/// Shared by every client an OpenFeature provider builds, so a dropped
/// selection is logged once per provider rather than on each context change.
final class FlagSelectionDropLog {
  bool logged = false;
}

final _ownerDropLogs = Expando<FlagSelectionDropLog>();

void shareFlagSelectionDropLog(Object owner, FlagSelectionDropLog dropLog) =>
    _ownerDropLogs[owner] = dropLog;

FlagSelectionDropLog? flagSelectionDropLogFor(Object owner) =>
    _ownerDropLogs[owner];

/// Canonicalizes [input] and logs why it is dropped, if it is.
FlagSelection? resolveFlagSelection(
  FlagSelection? input,
  FlagsLogger logger, {
  FlagSelectionDropLog? dropLog,
}) {
  final result = canonicalizeFlagSelection(input);
  final error = result.error;
  if (error != null && !(dropLog?.logged ?? false)) {
    dropLog?.logged = true;
    logger.error(
      'flagSelection was not sent (${error.reason}: ${error.limit}). '
      'Loading the full flag configuration.',
    );
  }
  return result.selection;
}

void logIgnoredFlagSelection(FlagsLogger logger, String reason) {
  logger.error(
    'flagSelection was ignored by the server ($reason). '
    'Loaded the full flag configuration.',
  );
}

const flagSelectionIgnoredHeader = 'dd-flag-selection-ignored';
const unknownFlagSelectionIgnoredReason = 'unknown';
const _serverIgnoredReasons = {
  'malformed_selection',
  'too_many_values',
  'invalid_key_pattern',
  'invalid_tag',
  'tag_load_failed',
};
// The longest known reason has 19 bytes; the limit bounds work on a long value.
const _maxIgnoredReasonLength = 32;

/// Returns the reason to report for the `DD-Flag-Selection-Ignored` header in
/// [headers], or null when it is absent or empty. A raw header value never
/// reaches logs: anything other than a known reason is `unknown`.
String? flagSelectionIgnoredReason(Map<String, String> headers) {
  String? value;
  for (final MapEntry(:key, value: headerValue) in headers.entries) {
    if (key.toLowerCase() == flagSelectionIgnoredHeader) {
      value = value == null ? headerValue : '$value, $headerValue';
    }
  }
  if (value == null || value.isEmpty) return null;
  if (value.length > _maxIgnoredReasonLength ||
      !_serverIgnoredReasons.contains(value)) {
    return unknownFlagSelectionIgnoredReason;
  }
  return value;
}

bool flagSelectionsEqual(FlagSelection? left, FlagSelection? right) {
  if (left == null || right == null) return left == right;
  return _listsEqual(left.tags, right.tags) &&
      _listsEqual(left.keyPatterns, right.keyPatterns);
}

Map<String, Object?> flagSelectionToJson(FlagSelection selection) => {
  'tags': selection.tags,
  'keyPatterns': selection.keyPatterns,
};

FlagSelection flagSelectionFromJson(Object? json) {
  if (json is! Map) {
    throw const FormatException('flagSelection must be a JSON object');
  }
  return FlagSelection(
    tags: _stringList(json['tags']),
    keyPatterns: _stringList(json['keyPatterns']),
  );
}

List<String> _stringList(Object? value) {
  if (value is! List || value.any((element) => element is! String)) {
    throw const FormatException('flagSelection lists must hold strings');
  }
  return List.unmodifiable(value.cast<String>());
}

List<String> _canonicalizeList(List<String> values) {
  final unique = <String>{};
  for (final value in values) {
    final trimmed = _trimWhiteSpace(value);
    if (trimmed.isNotEmpty) unique.add(trimmed);
  }
  // An over-limit list is dropped as too_many_values, so its order is unused.
  if (unique.length > maxFlagSelectionValues) return unique.toList();
  final keyed = [
    for (final value in unique) (value: value, bytes: utf8.encode(value)),
  ]..sort((left, right) => _compareBytes(left.bytes, right.bytes));
  return [for (final entry in keyed) entry.value];
}

// Every White_Space code point is in the BMP, so no surrogate pair is split.
String _trimWhiteSpace(String value) {
  var start = 0;
  var end = value.length;
  while (start < end && _whiteSpace.contains(value.codeUnitAt(start))) {
    start++;
  }
  while (end > start && _whiteSpace.contains(value.codeUnitAt(end - 1))) {
    end--;
  }
  return value.substring(start, end);
}

bool _isWellFormed(String value) {
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (index + 1 == value.length) return false;
      final next = value.codeUnitAt(++index);
      if (next < 0xDC00 || next > 0xDFFF) return false;
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return false;
    }
  }
  return true;
}

int _compareBytes(List<int> left, List<int> right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final difference = left[index] - right[index];
    if (difference != 0) return difference;
  }
  return left.length - right.length;
}

bool _listsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
