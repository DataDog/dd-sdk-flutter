// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024-Present Datadog, Inc.
import 'dart:async';

import 'package:collection/collection.dart';
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_tracking_http_client_example/scenario_config.dart';
import 'package:flutter/foundation.dart';

RecordingHttpServer? _mockHttpServer;

Future<RecordingServerClient> startMockServer() async {
  if (kIsWeb) {
    final client = RemoteRecordingServerClient();
    await client.startNewSession();
    return client;
  } else {
    if (_mockHttpServer == null) {
      _mockHttpServer = RecordingHttpServer();
      unawaited(_mockHttpServer!.start());
    }

    final client = LocalRecordingServerClient(_mockHttpServer!);
    await client.startNewSession();

    return client;
  }
}

/// Whether [visit] has an event for each of [resourceUrls] and [errorUrls], and
/// its last view event counts [resourceCount] resources. When [resourceCount]
/// is `null`, the view event must count every resource event received.
///
/// Events can arrive in any order, so this tells a test it can stop waiting.
bool isVisitComplete(
  RumViewVisit visit, {
  required List<String> resourceUrls,
  List<String> errorUrls = const [],
  int? resourceCount,
}) =>
    resourceUrls.every(
      (url) => visit.resourceEvents.any((event) => event.url.contains(url)),
    ) &&
    errorUrls.every(
      (url) => visit.errorEvents.any(
        (event) => event.resourceUrl?.contains(url) ?? false,
      ),
    ) &&
    visit.viewEvents.lastOrNull?.view.resourceCount ==
        (resourceCount ?? visit.resourceEvents.length);

/// [isVisitComplete] for the view of the scenario that makes the requests in
/// [config].
bool isRequestsVisitComplete(
  RumViewVisit visit,
  RumAutoInstrumentationScenarioConfig config, {
  int? resourceCount,
}) => isVisitComplete(
  visit,
  resourceUrls: [
    config.firstPartyGetUrl,
    ?config.firstPartyPostUrl,
    config.thirdPartyGetUrl,
    config.thirdPartyPostUrl,
    // Web reports the failed request as a resource, not an error.
    if (kIsWeb) config.firstPartyBadUrl,
  ],
  errorUrls: [if (!kIsWeb) config.firstPartyBadUrl],
  resourceCount: resourceCount,
);
