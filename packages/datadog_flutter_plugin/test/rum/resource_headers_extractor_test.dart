// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/src/rum/attributes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResourceHeadersExtractor', () {
    group('default headers', () {
      test('extracts default request headers', () {
        final extractor = ResourceHeadersExtractor();
        final headers = <String, List<String>>{
          'cache-control': ['no-cache'],
          'content-type': ['application/json'],
          'x-custom': ['value'],
        };
        final result = extractor.extractRequestHeaders(headers);
        expect(result, {
          'cache-control': 'no-cache',
          'content-type': 'application/json',
        });
      });

      test('extracts default response headers', () {
        final extractor = ResourceHeadersExtractor();
        final headers = <String, List<String>>{
          'cache-control': ['max-age=3600'],
          'etag': ['"abc123"'],
          'age': ['100'],
          'expires': ['Thu, 01 Dec 2025 16:00:00 GMT'],
          'content-type': ['text/html'],
          'content-encoding': ['gzip'],
          'vary': ['Accept-Encoding'],
          'content-length': ['1024'],
          'server-timing': ['total;dur=100'],
          'x-cache': ['HIT'],
          'x-custom': ['ignored'],
        };
        final result = extractor.extractResponseHeaders(headers);
        expect(result.length, 10);
        expect(result['cache-control'], 'max-age=3600');
        expect(result['etag'], '"abc123"');
        expect(result['age'], '100');
        expect(result['expires'], 'Thu, 01 Dec 2025 16:00:00 GMT');
        expect(result['content-type'], 'text/html');
        expect(result['content-encoding'], 'gzip');
        expect(result['vary'], 'Accept-Encoding');
        expect(result['content-length'], '1024');
        expect(result['server-timing'], 'total;dur=100');
        expect(result['x-cache'], 'HIT');
        expect(result.containsKey('x-custom'), false);
      });

      test('returns empty map when no matching headers', () {
        final extractor = ResourceHeadersExtractor();
        final headers = <String, List<String>>{
          'x-custom': ['value'],
          'x-other': ['value'],
        };
        final result = extractor.extractRequestHeaders(headers);
        expect(result, isEmpty);
      });
    });

    group('custom headers', () {
      test('includes defaults and custom headers', () {
        final extractor = ResourceHeadersExtractor(
          captureHeaders: ['x-request-id'],
        );
        final headers = <String, List<String>>{
          'cache-control': ['no-cache'],
          'content-type': ['application/json'],
          'x-request-id': ['abc-123'],
        };
        final result = extractor.extractRequestHeaders(headers);
        expect(result, {
          'cache-control': 'no-cache',
          'content-type': 'application/json',
          'x-request-id': 'abc-123',
        });
      });

      test('captures only custom headers when includeDefaults is false', () {
        final extractor = ResourceHeadersExtractor(
          includeDefaults: false,
          captureHeaders: ['x-request-id'],
        );
        final headers = <String, List<String>>{
          'cache-control': ['no-cache'],
          'content-type': ['application/json'],
          'x-request-id': ['abc-123'],
        };
        final result = extractor.extractRequestHeaders(headers);
        expect(result, {'x-request-id': 'abc-123'});
      });

      test('returns empty map when includeDefaults is false and no custom', () {
        final extractor = ResourceHeadersExtractor(
          includeDefaults: false,
        );
        final headers = <String, List<String>>{
          'cache-control': ['no-cache'],
        };
        final result = extractor.extractRequestHeaders(headers);
        expect(result, isEmpty);
      });

      test('deduplicates custom headers that overlap with defaults', () {
        final extractor = ResourceHeadersExtractor(
          captureHeaders: ['Cache-Control', 'x-request-id'],
        );
        final headers = <String, List<String>>{
          'cache-control': ['no-cache'],
          'x-request-id': ['abc-123'],
        };
        final result = extractor.extractRequestHeaders(headers);
        expect(result, {
          'cache-control': 'no-cache',
          'x-request-id': 'abc-123',
        });
      });
    });

    group('case insensitivity', () {
      test('matches headers case-insensitively', () {
        final extractor = ResourceHeadersExtractor();
        final headers = <String, List<String>>{
          'Content-Type': ['application/json'],
          'CACHE-CONTROL': ['no-cache'],
        };
        final result = extractor.extractRequestHeaders(headers);
        expect(result, {
          'content-type': 'application/json',
          'cache-control': 'no-cache',
        });
      });

      test('custom headers match case-insensitively', () {
        final extractor = ResourceHeadersExtractor(
          includeDefaults: false,
          captureHeaders: ['X-Request-ID'],
        );
        final headers = <String, List<String>>{
          'x-request-id': ['abc-123'],
        };
        final result = extractor.extractRequestHeaders(headers);
        expect(result, {'x-request-id': 'abc-123'});
      });
    });

    group('multi-value headers', () {
      test('joins multiple values with comma and space', () {
        final extractor = ResourceHeadersExtractor();
        final headers = <String, List<String>>{
          'cache-control': ['no-cache', 'no-store'],
          'vary': ['Accept-Encoding', 'Accept-Language'],
        };
        final response = extractor.extractResponseHeaders(headers);
        expect(response['cache-control'], 'no-cache, no-store');
        expect(response['vary'], 'Accept-Encoding, Accept-Language');
      });
    });

    group('security filtering', () {
      test('filters headers matching forbidden pattern', () {
        final extractor = ResourceHeadersExtractor(
          includeDefaults: false,
          captureHeaders: [
            'authorization',
            'cookie',
            'x-auth-token',
            'x-api-key',
            'x-secret-key',
            'x-access-key',
            'x-app-key',
            'x-csrf-token',
            'x-forwarded-for',
            'x-real-ip',
            'cf-connecting-ip',
            'true-client-ip',
            'x-password-hash',
            'x-credential-id',
            'bearer-token',
            'x-safe-header',
          ],
        );
        final headers = <String, List<String>>{
          'authorization': ['Bearer abc'],
          'cookie': ['session=xyz'],
          'x-auth-token': ['token123'],
          'x-api-key': ['key123'],
          'x-secret-key': ['secret123'],
          'x-access-key': ['access123'],
          'x-app-key': ['app123'],
          'x-csrf-token': ['csrf123'],
          'x-forwarded-for': ['1.2.3.4'],
          'x-real-ip': ['1.2.3.4'],
          'cf-connecting-ip': ['1.2.3.4'],
          'true-client-ip': ['1.2.3.4'],
          'x-password-hash': ['hash'],
          'x-credential-id': ['cred'],
          'bearer-token': ['bt'],
          'x-safe-header': ['safe'],
        };
        final result = extractor.extractRequestHeaders(headers);
        expect(result, {'x-safe-header': 'safe'});
      });

      test('filters forbidden headers even from defaults', () {
        // None of the defaults should match the forbidden pattern, but verify
        // that the filtering mechanism works if one were added
        final extractor = ResourceHeadersExtractor(
          captureHeaders: ['set-cookie'],
        );
        final headers = <String, List<String>>{
          'content-type': ['text/html'],
          'set-cookie': ['session=abc'],
        };
        final result = extractor.extractResponseHeaders(headers);
        expect(result, {'content-type': 'text/html'});
        expect(result.containsKey('set-cookie'), false);
      });
    });

    group('truncation', () {
      test('truncates values exceeding 128 bytes', () {
        final extractor = ResourceHeadersExtractor();
        final longValue = 'a' * 200;
        final headers = <String, List<String>>{
          'content-type': [longValue],
        };
        final result = extractor.extractRequestHeaders(headers);
        expect(utf8.encode(result['content-type']!).length,
            lessThanOrEqualTo(128));
      });

      test('truncates without splitting multi-byte characters', () {
        final extractor = ResourceHeadersExtractor(
          includeDefaults: false,
          captureHeaders: ['x-emoji'],
        );
        // Each emoji is 4 bytes in UTF-8. Fill to just over 128 bytes.
        final emoji = '😀'; // 4 bytes
        final value = emoji * 33; // 132 bytes
        final headers = <String, List<String>>{
          'x-emoji': [value],
        };
        final result = extractor.extractRequestHeaders(headers);
        final encodedResult = utf8.encode(result['x-emoji']!);
        expect(encodedResult.length, lessThanOrEqualTo(128));
        // Should be exactly 32 emojis = 128 bytes
        expect(encodedResult.length, 128);
      });
    });

    group('size limits', () {
      test('respects max 100 headers count', () {
        final headerNames = List.generate(
            110, (i) => 'x-header-${i.toString().padLeft(3, '0')}');
        final extractor = ResourceHeadersExtractor(
          includeDefaults: false,
          captureHeaders: headerNames,
        );
        final headers = <String, List<String>>{
          for (final name in headerNames) name: ['v'],
        };
        final result = extractor.extractRequestHeaders(headers);
        expect(result.length, 100);
      });

      test('respects 2KB total size limit', () {
        // Create headers that would exceed 2KB
        final headerNames =
            List.generate(30, (i) => 'x-h-${i.toString().padLeft(2, '0')}');
        final extractor = ResourceHeadersExtractor(
          includeDefaults: false,
          captureHeaders: headerNames,
        );
        // Each value is 100 bytes, name is ~7 bytes, so ~107 bytes per header
        // 30 headers * 107 bytes = 3210 bytes, exceeds 2048
        final headers = <String, List<String>>{
          for (final name in headerNames) name: ['x' * 100],
        };
        final result = extractor.extractRequestHeaders(headers);
        // Calculate total bytes
        var totalBytes = 0;
        for (final entry in result.entries) {
          totalBytes +=
              utf8.encode(entry.key).length + utf8.encode(entry.value).length;
        }
        expect(totalBytes, lessThanOrEqualTo(2048));
        expect(result.length, lessThan(30));
      });

      test(
          'skips an oversized header but keeps capturing smaller subsequent ones',
          () {
        // Burn most of the 2048-byte budget with 16 fillers (~122 bytes each
        // ≈ 1952 bytes), leaving ~96 bytes free. A subsequent "medium" header
        // (~117 bytes) does not fit and must be skipped; a "tiny" header
        // listed after it (~7 bytes) must still be captured. This exercises
        // continue-vs-break on the byte-budget check.
        final fillers =
            List.generate(16, (i) => 'x-fill-${i.toString().padLeft(2, '0')}');
        final extractor = ResourceHeadersExtractor(
          includeDefaults: false,
          captureHeaders: [...fillers, 'x-medium-overflow', 'x-tiny'],
        );
        final headers = <String, List<String>>{
          for (final name in fillers) name: ['v' * 113],
          'x-medium-overflow': ['m' * 100],
          'x-tiny': ['v'],
        };
        final result = extractor.extractRequestHeaders(headers);
        expect(result.containsKey('x-medium-overflow'), isFalse);
        expect(result['x-tiny'], 'v');
      });

      test(
          'preserves default response headers when many custom headers are listed first in the input',
          () {
        // When many large custom headers come before defaults in the input
        // map order, defaults must still survive the byte budget.
        final customNames = List.generate(
            30, (i) => 'x-custom-${i.toString().padLeft(2, '0')}');
        final extractor = ResourceHeadersExtractor(
          captureHeaders: customNames,
        );
        // Each custom value is 100 bytes — 30 customs alone would blow the
        // 2KB budget if iterated in input order before content-type.
        final headers = <String, List<String>>{
          for (final name in customNames) name: ['x' * 100],
          'content-type': ['text/html'],
          'etag': ['"abc"'],
        };
        final result = extractor.extractResponseHeaders(headers);
        expect(result['content-type'], 'text/html');
        expect(result['etag'], '"abc"');
      });
    });

    group('toResourceAttributes', () {
      test('returns map with internal attribute keys', () {
        final extractor = ResourceHeadersExtractor();
        final requestHeaders = <String, List<String>>{
          'content-type': ['application/json'],
        };
        final responseHeaders = <String, List<String>>{
          'content-type': ['text/html'],
          'etag': ['"abc"'],
        };
        final attrs = extractor.toResourceAttributes(
          requestHeaders,
          responseHeaders,
        );
        expect(attrs[DatadogRumPlatformAttributeKey.requestHeaders], {
          'content-type': 'application/json',
        });
        expect(attrs[DatadogRumPlatformAttributeKey.responseHeaders], {
          'content-type': 'text/html',
          'etag': '"abc"',
        });
      });

      test('omits empty header maps from attributes', () {
        final extractor = ResourceHeadersExtractor();
        final attrs = extractor.toResourceAttributes(
          const {},
          const {},
        );
        expect(attrs, isEmpty);
      });

      test('omits request headers when none match', () {
        final extractor = ResourceHeadersExtractor();
        final attrs = extractor.toResourceAttributes(
          {
            'x-custom': ['value']
          },
          {
            'content-type': ['text/html']
          },
        );
        expect(attrs.containsKey(DatadogRumPlatformAttributeKey.requestHeaders),
            false);
        expect(attrs[DatadogRumPlatformAttributeKey.responseHeaders], {
          'content-type': 'text/html',
        });
      });
    });
  });
}
