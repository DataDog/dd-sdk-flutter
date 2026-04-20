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

/// Controls how captured `TextStyle.fontFamily` values are rewritten before
/// they are sent as `SRTextStyle.family` on text wireframes.
///
/// Custom callbacks are intentionally not supported: Session Replay builds
/// wireframes in a background isolate, which cannot serialize Dart closures
/// — use [FontFamilyTransformConfig.rules] instead.
enum FontFamilyStrategy {
  /// Preserves reasonable CSS-compatible family names while
  /// cleaning up Flutter-specific artifacts: strips `packages/<pkg>/`
  /// asset-prefix, drops Flutter / platform sentinels that are not
  /// valid on the web (e.g. `CupertinoSystemText`, `.SF UI Text`),
  /// splits EditableText comma-joined fallback lists, quotes names
  /// with spaces, and always appends a generic CSS fallback
  /// (`sans-serif`) when none is present so the replay player has a
  /// guaranteed fallback. Yields the default replay font stack when
  /// the captured family is empty or fully sentinel.
  smart,

  /// Always emits the single hardcoded CSS stack
  /// `-apple-system, BlinkMacSystemFont, Roboto, sans-serif`,
  /// regardless of the captured family. Matches the native SDK
  /// behavior and is the safest choice if you do not want any
  /// Flutter font names leaving the device.
  fallback,

  /// No transform is applied—the raw `TextStyle.fontFamily` (or
  /// comma-joined fallback list from EditableText) captured by the
  /// recorders is emitted verbatim on the wire. Intended for
  /// debugging and backwards compatibility with the previous
  /// behavior; not recommended for production because values like
  /// `packages/google_fonts/Roboto` or `""` may not render correctly
  /// in the replay player.
  none,
}

/// Serialized font-family rewriting rules passed to the processor isolate.
///
/// Use [rules] for exact-match overrides only (no callbacks).
class FontFamilyTransformConfig {
  /// Default is [FontFamilyStrategy.none] for backwards compatibility; set
  /// [FontFamilyStrategy.smart] for web-friendly font stacks.
  final FontFamilyStrategy strategy;

  /// Exact-match overrides, applied per comma-separated token before built-in
  /// normalization when [strategy] is [FontFamilyStrategy.smart]. Keys are
  /// case-sensitive—match either the captured token as recorded (trimmed /
  /// outer quotes removed) or the same token after stripping a
  /// `packages/<pkg>/` asset prefix. Values may be comma-separated stacks.
  ///
  /// Use an empty string key (`''`) in [rules] to supply a custom CSS stack
  /// when the captured family is empty or becomes empty after dropping
  /// sentinels; if absent, [FontFamilyStrategy.smart] uses the default iOS-parity
  /// stack in those cases.
  final Map<String, String> rules;

  const FontFamilyTransformConfig({
    this.strategy = FontFamilyStrategy.none,
    this.rules = const {},
  });
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

  /// Whether Session Replay should start recording when it is initialized.
  /// When `false`, call [DatadogSessionReplay.startRecording] to begin
  /// recording.
  ///
  /// Defaults to `true`.
  bool startRecordingImmediately;

  /// Rewrites captured font family strings into web-compatible CSS stacks in
  /// the processor isolate before snapshots are serialized.
  ///
  /// Defaults to [FontFamilyStrategy.none] so existing behavior is unchanged;
  /// use [FontFamilyStrategy.smart] for web-friendly normalization.
  FontFamilyTransformConfig fontFamilyTransform;

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
    this.startRecordingImmediately = true,
    this.fontFamilyTransform = const FontFamilyTransformConfig(),
    this.iconRasterLogicalSize = 20.0,
  });
}

extension SessionReplayExtension on DatadogConfiguration {
  void enableSessionReplay(DatadogSessionReplayConfiguration config) {
    addPlugin(DatadogSessionReplayPluginConfiguration(configuration: config));
  }
}
