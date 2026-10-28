// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(WebViewSlotRegistry.debugReset);

  test('returns the slot registered for a WebView', () {
    WebViewSlotRegistry.register(3, '4370600960', owner: Object());

    expect(WebViewSlotRegistry.slotId(3), '4370600960');
    expect(WebViewSlotRegistry.slotId(4), isNull);
  });

  test('re-registering a WebView replaces its slot', () {
    final owner = Object();
    WebViewSlotRegistry.register(3, 'first', owner: owner);
    WebViewSlotRegistry.register(3, 'second', owner: owner);

    expect(WebViewSlotRegistry.slotId(3), 'second');
  });

  test('removes the slot when its owner is finalized', () {
    WebViewSlotRegistry.register(3, '4370600960', owner: Object());
    final generation = WebViewSlotRegistry.debugGeneration(3)!;

    WebViewSlotRegistry.debugFinalize(3, generation: generation);

    expect(WebViewSlotRegistry.slotId(3), isNull);
  });

  test(
    'a late finalizer does not remove the slot of a WebView reusing the identifier',
    () {
      // The first WebView is collected, but its finalizer only runs after a new
      // WebView was assigned the same identifier and tracked.
      WebViewSlotRegistry.register(3, 'old', owner: Object());
      final oldGeneration = WebViewSlotRegistry.debugGeneration(3)!;
      WebViewSlotRegistry.register(3, 'new', owner: Object());

      WebViewSlotRegistry.debugFinalize(3, generation: oldGeneration);

      expect(WebViewSlotRegistry.slotId(3), 'new');
    },
  );
}
