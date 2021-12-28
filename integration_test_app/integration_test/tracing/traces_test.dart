// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.
import 'dart:convert';

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

  expect(span.source, 'flutter');
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

      expect(span.span['meta.class'], '_TracesScenarioState');
    }

    expect(spanLog[0].name, 'data downloading');
    expect(spanLog[1].name, 'data presentation');
    expect(spanLog[2].name, 'view loading');

    var traceId = spanLog[0].traceId;
    expect(traceId, spanLog[1].traceId);
    expect(traceId, spanLog[2].traceId);

    var rootSpanId = spanLog[2].spanId;
    expect(rootSpanId, spanLog[0].parentSpanId);
    expect(rootSpanId, spanLog[1].parentSpanId);

    expect(spanLog[0].isRootSpan, isNull);
    expect(spanLog[1].isRootSpan, isNull);
    expect(spanLog[2].isRootSpan, 1);

    expect(spanLog[0].span['meta.data.kind'], 'image');
    expect(spanLog[0].span['meta.data.url'], 'https://example.com/image.png');

    expect(spanLog[0].resource, 'GET /image.png');
    expect(spanLog[1].resource, spanLog[1].name);
    expect(spanLog[2].resource, spanLog[2].name);

    expect(spanLog[0].isError, 0);
    expect(spanLog[1].isError, 1);
    expect(spanLog[2].isError, 0);

    expect(logs.length, 2);
    expect(logs[0].status, 'info');
    expect(logs[0].message, 'download progress');
    expect(logs[0].log['progress'], 0.99);
    expect(
        logs[0].log['dd.trace_id'], isDecimalVersionOfHex(spanLog[0].traceId));
    expect(logs[0].log['dd.span_id'], isDecimalVersionOfHex(spanLog[0].spanId));

    expect(logs[1].status, 'error');
    expect(logs[1].message, contains('PlatformException'));
    expect(logs[1].log['error.kind'], contains('PlatformException'));
    expect(logs[1].log['error.message'], contains('PlatformException'));
    // expect(logs[0].log['error.stack'], contains('_TracesScenarioState'));
    expect(
        logs[1].log['dd.trace_id'], isDecimalVersionOfHex(spanLog[1].traceId));
    expect(logs[1].log['dd.span_id'], isDecimalVersionOfHex(spanLog[1].spanId));
  });
}
