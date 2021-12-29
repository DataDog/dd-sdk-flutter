// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../common.dart';
import '../logging/log_decoder.dart';
import '../tools/mock_http_sever.dart';
import 'span_decoder.dart';

void _assertCommonSpanMetadata(SpanDecoder span) {
  expect(span.type, 'custom');
  expect(span.environment, 'prod');

  // RUMM- Android does not properly override 'source' on traces
  if (Platform.isIOS) {
    expect(span.source, 'flutter');
  }
  expect(span.tracerVersion, DatadogSdk().version);
  expect(span.appVersion, '1.0.0');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('test tracing scenario', (WidgetTester tester) async {
    await openTestScenario(tester, 'Traces Scenario');

    var requestsLog = <RequestLog>[];
    var spanLog = <SpanDecoder>[];
    var logs = <LogDecoder>[];

    await mockHttpServer!.pollRequests(
      const Duration(seconds: 30),
      (requests) {
        requestsLog.addAll(requests);
        requests.map((e) => e.data.split('\n')).expand((e) => e).forEach((e) {
          var envelope = json.decode(e);
          if (envelope is Map<String, Object?>) {
            var spanList = envelope['spans'];
            envelope.remove('spans');
            if (spanList != null && spanList is List<dynamic>) {
              for (var span in spanList) {
                spanLog.add(SpanDecoder(envelope: envelope, span: span));
              }
            }
          } else if (envelope is List<dynamic>) {
            for (var e in envelope) {
              logs.add(LogDecoder(e as Map<String, dynamic>));
            }
          }
        });

        return spanLog.length >= 3;
      },
    );
    expect(spanLog.length, greaterThanOrEqualTo(3));

    for (var request in requestsLog) {
      expect(request.requestMethod, 'POST');
      expect(request.requestedUrl.contains('?'), isFalse);
    }

    for (var span in spanLog) {
      _assertCommonSpanMetadata(span);

      // Not sure if this property is sent with Android
      expect(span.metaClass, '_TracesScenarioState');
    }

    final rootSpan = spanLog.firstWhereOrNull((s) => s.name == 'view loading');
    final downloadingSpan =
        spanLog.firstWhereOrNull((s) => s.name == 'data downloading');
    final presentationSpan =
        spanLog.firstWhereOrNull((s) => s.name == 'data presentation');
    expect(rootSpan, isNotNull);
    expect(downloadingSpan, isNotNull);
    expect(presentationSpan, isNotNull);

    var traceId = rootSpan!.traceId;
    expect(traceId, downloadingSpan!.traceId);
    expect(traceId, presentationSpan!.traceId);

    var rootSpanId = rootSpan.spanId;
    expect(rootSpanId, downloadingSpan.parentSpanId);
    expect(rootSpanId, presentationSpan.parentSpanId);

    expect(rootSpan.isRootSpan, 1);
    expect(downloadingSpan.isRootSpan, isNull);
    expect(presentationSpan.isRootSpan, isNull);

    expect(downloadingSpan.getTag<String>('data.kind'), 'image');
    expect(downloadingSpan.getTag<String>('data.url'),
        'https://example.com/image.png');
    // TODO: Android may not recognize 'resource.name' as a tag to set on the root object
    if (Platform.isIOS) {
      expect(downloadingSpan.resource, 'GET /image.png');
    } else if (Platform.isAndroid) {
      expect(downloadingSpan.getTag<String>('resource.name'), 'GET /image.png');
    }

    expect(presentationSpan.resource, presentationSpan.name);
    expect(rootSpan.resource, rootSpan.name);

    expect(rootSpan.isError, 0);
    expect(downloadingSpan.isError, 0);
    expect(presentationSpan.isError, 1);

    expect(logs.length, 2);
    expect(logs[0].status, Platform.isIOS ? 'info' : 'trace');
    expect(logs[0].message, 'download progress');
    expect(logs[0].log['progress'], 0.99);
    expect(logs[0].log['dd.trace_id'],
        isDecimalVersionOfHex(downloadingSpan.traceId));
    expect(logs[0].log['dd.span_id'],
        isDecimalVersionOfHex(downloadingSpan.spanId));

    expect(logs[1].status, Platform.isIOS ? 'error' : 'trace');
    expect(logs[1].message, contains('PlatformException'));
    if (Platform.isIOS) {
      expect(logs[1].log['error.kind'], contains('PlatformException'));
      expect(logs[1].log['error.message'], contains('PlatformException'));
    } else if (Platform.isAndroid) {
      // TODO: RUMM- Android doesn't use "error.kind" or "error.message" for errors
      expect(logs[1].log['message'], contains('PlatformException'));
    }
    // TODO: RUMM-1852 Better stack trace handling
    // expect(logs[0].log['error.stack'], contains('_TracesScenarioState'));
    expect(logs[1].log['dd.trace_id'],
        isDecimalVersionOfHex(presentationSpan.traceId));
    expect(logs[1].log['dd.span_id'],
        isDecimalVersionOfHex(presentationSpan.spanId));
  });
}
