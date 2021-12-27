// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'dart:convert';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';
import 'tools/mock_http_sever.dart';

void _assertCommonSpanMetadata(SpanDecoder span) {
  expect(span.type, 'custom');
  expect(span.environment, 'prod');

  expect(span.source, 'flutter');
  expect(span.tracerVersion, DatadogSdk().version);
  expect(span.appVersion, '1.0.0');
}

class SpanDecoder {
  final Map<String, Object?> envelope;
  final Map<String, Object?> span;

  String get environment => envelope['env'] as String;

  String get type => span['type'] as String;
  String get name => span['name'] as String;
  String get traceId => span['trace_id'] as String;
  String get spanId => span['span_id'] as String;
  String? get parentSpanId => span['parent_id'] as String?;
  String get resource => span['resource'] as String;
  int get isError => span['error'] as int;

  // Meta properties
  String get source => span['meta._dd.source'] as String;
  String get tracerVersion => span['meta.tracer.version'] as String;
  String get appVersion => span['meta.version'] as String;

  // Metrics properties
  int? get isRootSpan => span['metrics._top_level'] as int?;

  SpanDecoder({required this.envelope, required this.span});
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('test logging scenario', (WidgetTester tester) async {
    await openTestScenario(tester, 'Traces Scenario');

    var requestsLog = <RequestLog>[];
    var spanLog = <SpanDecoder>[];
    //var logs = <LogMatcher>[];

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
          } else {}
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
  });
}
