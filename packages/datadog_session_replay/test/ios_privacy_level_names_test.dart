// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter_test/flutter_test.dart';

// On iOS, `enable` passes the privacy levels to native by their `name`, and
// native maps those exact strings to its own levels (falling back to the most
// restrictive one for anything else). Renaming a value must update
// `FlutterSessionReplayConfiguration` in the iOS bridge too.
void main() {
  test('text and input privacy level names match what iOS maps', () {
    expect(TextAndInputPrivacyLevel.values.map((level) => level.name), [
      'maskSensitiveInputs',
      'maskAllInputs',
      'maskAll',
    ]);
  });

  test('image privacy level names match what iOS maps', () {
    expect(ImagePrivacyLevel.values.map((level) => level.name), [
      'maskNonAssetsOnly',
      'maskAll',
      'maskNone',
    ]);
  });

  test('touch privacy level names match what iOS maps', () {
    expect(TouchPrivacyLevel.values.map((level) => level.name), [
      'show',
      'hide',
    ]);
  });
}
