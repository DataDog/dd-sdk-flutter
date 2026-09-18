// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags/src/intake_platform.dart';
import 'package:datadog_flags/src/intake_request.dart';
import 'package:test/test.dart';

void main() {
  test('only builds the request body for the current platform', () {
    var nativeBodyBuildCount = 0;
    var webBodyBuildCount = 0;

    final request = buildFlagsIntakeRequest(
      endpoint: Uri.parse('https://example.com/api/v2/flagevaluation'),
      clientToken: 'client-token',
      nativeContentType: 'application/json',
      nativeBodyBuilder: () {
        nativeBodyBuildCount += 1;
        return 'native-body';
      },
      webBodyBuilder: () {
        webBodyBuildCount += 1;
        return 'web-body';
      },
    );

    if (isWebFlagsIntake) {
      expect(request.body, 'web-body');
      expect(nativeBodyBuildCount, 0);
      expect(webBodyBuildCount, 1);
    } else {
      expect(request.body, 'native-body');
      expect(nativeBodyBuildCount, 1);
      expect(webBodyBuildCount, 0);
    }
  });
}
