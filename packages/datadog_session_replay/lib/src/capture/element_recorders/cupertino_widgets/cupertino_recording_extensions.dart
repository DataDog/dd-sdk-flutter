// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';

extension CupertinoColorResolver on Color {
  Color resolveColor(Element element) {
    final resolved = CupertinoDynamicColor.resolve(this, element);
    return Color.from(
        alpha: resolved.a,
        red: resolved.r,
        green: resolved.g,
        blue: resolved.b);
  }
}
