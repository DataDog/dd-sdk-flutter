// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

import 'src/datadog_session_replay_plugin.dart';

export 'src/datadog_session_replay.dart' show DatadogSessionReplay;
export 'src/widgets.dart' show SessionReplayCapture, SessionReplayPrivacy;

/// Available privacy levels for text and input masking in Session Replay.
enum TextAndInputPrivacyLevel {
  /// Show all text except sensitive inputs (those with [EditableText.obscureText] set)
  maskSensitiveInputs,

  /// Mask all input fields, such as TextField, Checkbox, Switch, etc.
  maskAllInputs,

  /// Mask all text and inputs, including all Text widgets.
  maskAll,
}

/// Available privacy levels for image masking in Session Replay.
enum ImagePrivacyLevel {
  /// Only images that are assets bundled with the application will be recorded.
  maskNonAssetsOnly,

  /// No images will be recorded.
  maskAll,

  // All images will be recorded, including ones downloaded from the internet.
  maskNone,
}

/// Available privacy levels for touch masking in Session Replay.
///
/// Unlike other privacy levels, the [TouchPrivacyLevel] is global and cannot
/// currently be overriden in subtrees using the [SessionReplayPrivacy] widget.
enum TouchPrivacyLevel {
  /// Show all user touches.
  show,

  // Hide all user touches.
  hide,
}

/// Configuration options for Session Replay, including
/// default privacy levels.
class DatadogSessionReplayConfiguration {
  /// The sampling rate for Session Replay. This is applied in addition to the
  /// RUM session sample rate.
  ///
  /// It must be a number between 0.0 and 100.0, where 0 means no replays will
  /// be recorded and 100 means all sampled RUM sessions will contain replay.
  ///
  /// Note: This sample rate is applied in addition to the RUM sample rate. For
  /// example, if RUM uses a sample rate of 80% and Session Replay uses a sample
  /// rate of 20%, it means that out of all user sessions, 80% will be included
  /// in RUM, and within those sessions, only 20% will have replays.
  double replaySampleRate;

  /// Defines the way text and input (e.g. TextFields and CheckBoxes) should be
  /// captured.
  ///
  /// Defaults to [TextAndInputPrivacyLevel.maskAll]
  TextAndInputPrivacyLevel textAndInputPrivacyLevel;

  /// Defines the way images should be captured.
  ///
  /// Defaults to [ImagePrivacyLevel.maskAll]
  ImagePrivacyLevel imagePrivacyLevel;

  /// Defines whether user touches (e.g. taps) should be captured
  ///
  /// Defaults to [TouchPrivacyLevel.hide]
  TouchPrivacyLevel touchPrivacyLevel;

  String? customEndpoint;

  /// Logical size (dp) at which icon glyphs are rasterized for session replay.
  ///
  /// The replay player scales the bitmap to the widget's on-screen bounds.
  /// Smaller values reduce CPU/GPU work and memory; larger values improve
  /// sharpness when icons are displayed big.
  ///
  /// Defaults to `20`.
  double iconRasterLogicalSize;

  DatadogSessionReplayConfiguration({
    required this.replaySampleRate,
    this.textAndInputPrivacyLevel = TextAndInputPrivacyLevel.maskAll,
    this.imagePrivacyLevel = ImagePrivacyLevel.maskAll,
    this.touchPrivacyLevel = TouchPrivacyLevel.hide,
    this.customEndpoint,
    this.iconRasterLogicalSize = 20.0,
  });
}

extension SessionReplayExtension on DatadogConfiguration {
  void enableSessionReplay(DatadogSessionReplayConfiguration config) {
    addPlugin(DatadogSessionReplayPluginConfiguration(configuration: config));
  }
}
