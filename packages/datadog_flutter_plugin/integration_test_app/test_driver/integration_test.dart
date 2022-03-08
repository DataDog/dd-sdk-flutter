// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:async';

import 'package:integration_test/integration_test_driver.dart';

import '../integration_test/tools/mock_http_sever.dart';

Future<void> main() async {
  final server = RecordingHttpServer();
  await server.start();

  await integrationDriver();
}
