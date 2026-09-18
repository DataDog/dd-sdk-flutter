// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

extension Waiter on WidgetTester {
  Future<bool> waitFor(
    Finder finder,
    Duration timeout,
    bool Function(Element e) predicate,
  ) async {
    var endTime = DateTime.now().add(timeout);
    bool wasFound = false;
    while (DateTime.now().isBefore(endTime) && !wasFound) {
      final element = finder.evaluate().firstOrNull;
      if (element != null) {
        wasFound = predicate(element);
      }
      await pumpAndSettle();
    }

    return wasFound;
  }
}
