// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024-Present Datadog, Inc.

import 'package:datadog_inappwebview_tracking/src/datadog_inappwebview_tracking_method_channel.dart';
import 'package:datadog_inappwebview_tracking/src/datadog_inappwebview_tracking_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DatadogInAppWebViewTrackingPlatform initialPlatform =
      DatadogInAppWebViewTrackingPlatform.instance;

  test(
      '$MethodChannelDatadogInAppWebViewTracking is the default platform instance',
      () {
    expect(initialPlatform,
        isInstanceOf<MethodChannelDatadogInAppWebViewTracking>());
  });
}
