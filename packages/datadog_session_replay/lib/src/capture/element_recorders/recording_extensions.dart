// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/widgets.dart';

import '../../../datadog_session_replay.dart';
import '../../sr_data_models.dart';
import '../recorder.dart';

extension SRTextAlignment on TextAlign {
  SRHorizontalAlignment getSrHorizontalAlignment(TextDirection? textDirection) {
    switch (this) {
      case TextAlign.left:
      case TextAlign.justify:
        return SRHorizontalAlignment.left;
      case TextAlign.start:
        return textDirection == TextDirection.rtl
            ? SRHorizontalAlignment.right
            : SRHorizontalAlignment.left;
      case TextAlign.right:
        return SRHorizontalAlignment.right;
      case TextAlign.end:
        return textDirection == TextDirection.rtl
            ? SRHorizontalAlignment.left
            : SRHorizontalAlignment.right;
      case TextAlign.center:
        return SRHorizontalAlignment.center;
    }
  }
}

extension TreeCapturePrivacyExtension on TreeCapturePrivacy {
  bool get shouldMaskInputs =>
      textAndInputPrivacyLevel == TextAndInputPrivacyLevel.maskAllInputs ||
      textAndInputPrivacyLevel == TextAndInputPrivacyLevel.maskAll;
}

extension BorderSideStateResolver on BorderSide? {
  BorderSide? resolveSide(Set<WidgetState> states) {
    if (this is WidgetStateProperty) {
      return WidgetStateProperty.resolveAs<BorderSide?>(this, states);
    }
    if (!states.contains(WidgetState.selected)) {
      return this;
    }
    return null;
  }
}
