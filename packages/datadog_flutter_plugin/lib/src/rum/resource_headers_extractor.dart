// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';

// Dart 3.9 moved made it so meta is no longer needed for `@internal`, but we
// still need it for versions below 3.9.
// ignore: unnecessary_import
import 'package:meta/meta.dart';

import 'attributes.dart';

/// Default request headers captured when [includeDefaults] is true.
const List<String> _defaultRequestHeaders = [
  'cache-control',
  'content-type',
];

/// Default response headers captured when [includeDefaults] is true.
const List<String> _defaultResponseHeaders = [
  'cache-control',
  'etag',
  'age',
  'expires',
  'content-type',
  'content-encoding',
  'vary',
  'content-length',
  'server-timing',
  'x-cache',
];

/// Regex pattern matching header names that must never be captured, even if
/// explicitly configured. Aligned with Android and iOS SDKs.
final RegExp _forbiddenHeaderPattern = RegExp(
  r'(token|cookie|secret|authorization|password|credential|bearer|(api|secret|access|app).?key|forwarded|real.?ip|connecting.?ip|client.?ip)',
  caseSensitive: false,
);

/// Maximum total size of collected header content per direction (request or
/// response), in bytes.
const int _headerSizeLimitBytes = 2048;

/// Maximum byte length of a single header value. Values exceeding this are
/// truncated.
const int _maxHeaderValueBytes = 128;

/// Maximum number of headers captured per direction.
const int _maxHeadersCount = 100;

/// Configuration for capturing HTTP request and response headers in RUM
/// resource events.
///
/// When provided to [DatadogRumConfiguration.trackResourceHeaders], the SDK
/// captures matching headers from intercepted HTTP requests and responses.
///
/// ```dart
/// DatadogRumConfiguration(
///   applicationId: 'app-id',
///   trackResourceHeaders: ResourceHeadersExtractor(),
/// )
/// ```
///
/// By default, a set of safe headers is captured (e.g. `cache-control`,
/// `content-type`, `etag`). Pass [captureHeaders] to capture additional
/// headers, or set [includeDefaults] to `false` to capture only the
/// specified custom headers.
///
/// Headers whose names match a security pattern (e.g. `authorization`,
/// `cookie`, `token`) are **never** captured, even if explicitly listed.
class ResourceHeadersExtractor {
  /// Whether to include the default safe headers in addition to any
  /// [captureHeaders].
  final bool includeDefaults;

  /// Additional header names to capture (case-insensitive).
  final List<String> captureHeaders;

  final Set<String> _requestHeaders;
  final Set<String> _responseHeaders;

  /// Creates a header extractor.
  ///
  /// When [includeDefaults] is `true` (the default), standard safe headers
  /// are automatically captured. Additional headers can be specified via
  /// [captureHeaders].
  ResourceHeadersExtractor({
    this.includeDefaults = true,
    this.captureHeaders = const [],
  })  : _requestHeaders = _buildHeaderSet(
          includeDefaults ? _defaultRequestHeaders : const [],
          captureHeaders,
        ),
        _responseHeaders = _buildHeaderSet(
          includeDefaults ? _defaultResponseHeaders : const [],
          captureHeaders,
        );

  /// Extracts matching request headers from the provided header map.
  ///
  /// Returns a map of lowercase header names to their (potentially truncated)
  /// values. Security-filtered headers are excluded. Size limits are enforced.
  @internal
  Map<String, String> extractRequestHeaders(Map<String, List<String>> headers) {
    return _extractHeaders(headers, _requestHeaders);
  }

  /// Extracts matching response headers from the provided header map.
  ///
  /// Returns a map of lowercase header names to their (potentially truncated)
  /// values. Security-filtered headers are excluded. Size limits are enforced.
  @internal
  Map<String, String> extractResponseHeaders(
      Map<String, List<String>> headers) {
    return _extractHeaders(headers, _responseHeaders);
  }

  /// Convenience method that extracts both request and response headers and
  /// returns them as a map of internal attributes suitable for merging into
  /// `stopResource()` attributes.
  @internal
  Map<String, Object?> toResourceAttributes(
    Map<String, List<String>> requestHeaders,
    Map<String, List<String>> responseHeaders,
  ) {
    final result = <String, Object?>{};
    final extracted = extractRequestHeaders(requestHeaders);
    if (extracted.isNotEmpty) {
      result[DatadogRumPlatformAttributeKey.requestHeaders] = extracted;
    }
    final extractedResponse = extractResponseHeaders(responseHeaders);
    if (extractedResponse.isNotEmpty) {
      result[DatadogRumPlatformAttributeKey.responseHeaders] =
          extractedResponse;
    }
    return result;
  }

  static Map<String, String> _extractHeaders(
    Map<String, List<String>> headers,
    Set<String> allowedHeaders,
  ) {
    if (headers.isEmpty || allowedHeaders.isEmpty) return const {};

    final inputByLowerName = <String, List<String>>{};
    for (final entry in headers.entries) {
      inputByLowerName[entry.key.toLowerCase()] = entry.value;
    }

    final result = <String, String>{};
    var totalBytes = 0;

    for (final lowerName in allowedHeaders) {
      if (result.length >= _maxHeadersCount) break;

      final values = inputByLowerName[lowerName];
      if (values == null) continue;

      final joinedValue = values.join(', ');
      final truncatedValue = _truncateToUtf8ByteSize(
        joinedValue,
        _maxHeaderValueBytes,
      );

      final nameBytes = utf8.encode(lowerName).length;
      final valueBytes = utf8.encode(truncatedValue).length;
      final entrySize = nameBytes + valueBytes;

      // Skip this header but keep trying smaller ones — matches dd-sdk-android.
      if (totalBytes + entrySize > _headerSizeLimitBytes) continue;

      result[lowerName] = truncatedValue;
      totalBytes += entrySize;
    }

    return result;
  }

  /// Builds a deduplicated, lowercase set of header names from defaults and
  /// custom headers. Headers matching [_forbiddenHeaderPattern] are filtered
  /// out at build time so the security filter does not run per-call.
  static Set<String> _buildHeaderSet(
    List<String> defaults,
    List<String> custom,
  ) {
    final result = <String>{};
    for (final h in defaults) {
      final lower = h.toLowerCase();
      if (_forbiddenHeaderPattern.hasMatch(lower)) continue;
      result.add(lower);
    }
    for (final h in custom) {
      final lower = h.toLowerCase();
      if (_forbiddenHeaderPattern.hasMatch(lower)) continue;
      result.add(lower);
    }
    return result;
  }

  /// Truncates [value] to at most [maxBytes] UTF-8 bytes without splitting
  /// multi-byte characters.
  static String _truncateToUtf8ByteSize(String value, int maxBytes) {
    final encoded = utf8.encode(value);
    if (encoded.length <= maxBytes) return value;

    // Walk back from maxBytes to avoid splitting a multi-byte character.
    var end = maxBytes;
    while (end > 0 && (encoded[end] & 0xC0) == 0x80) {
      end--;
    }
    return utf8.decode(encoded.sublist(0, end));
  }
}
