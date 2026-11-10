// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WebViewSlotRegistry registry;

  setUp(() => registry = WebViewSlotRegistry());

  test('returns the slot registered for a WebView', () {
    registry.register(3, '4370600960', owner: Object());

    expect(registry.slotId(3), '4370600960');
    expect(registry.slotId(4), isNull);
  });

  test('re-registering a WebView replaces its slot', () {
    final owner = Object();
    registry.register(3, 'first', owner: owner);
    registry.register(3, 'second', owner: owner);

    expect(registry.slotId(3), 'second');
  });

  test('removes the slot when its owner is finalized', () {
    registry.register(3, '4370600960', owner: Object());
    final registrationId = registry.debugRegistrationId(3)!;

    registry.removeIfCurrent(3, registrationId);

    expect(registry.slotId(3), isNull);
  });

  test(
    'a late finalizer does not remove the slot of a WebView reusing the identifier',
    () {
      // The first WebView is collected, but its finalizer only runs after a new
      // WebView was assigned the same identifier and tracked.
      registry.register(3, 'old', owner: Object());
      final oldRegistrationId = registry.debugRegistrationId(3)!;
      registry.register(3, 'new', owner: Object());

      registry.removeIfCurrent(3, oldRegistrationId);

      expect(registry.slotId(3), 'new');
    },
  );
}
