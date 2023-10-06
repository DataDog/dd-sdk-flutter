// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_tracking_http_client/datadog_tracking_http_client.dart';
import 'package:flutter/material.dart';

import 'my_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = DatadogAttachConfiguration(
    detectLongTasks: true,
    reportFlutterPerformance: true,
  )..enableHttpTracking();

  await DatadogSdk.instance.attachToExisting(config);

  runApp(MyApp());
}
