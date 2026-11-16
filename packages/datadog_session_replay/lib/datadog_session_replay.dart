// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

import 'src/capture/element_recorders/raster_resources.dart'
    show defaultMaxImagePixelBudget;
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
  /// Flutter font names leaving the device. The one exception is
  /// `MaterialIcons`, which the replay player bundles and which
  /// [Icon] glyphs need in order to render.
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

/// Controls how text widgets ([RichText], and widgets that build one, such as
/// [Text]) are recorded.
enum TextCaptureMode {
  /// Text is sent as text, and the replay player draws it with fonts available
  /// in the viewer's browser. Uploads are small, but fonts, weights, letter
  /// spacing and line breaks can differ from the device. See
  /// [DatadogSessionReplayConfiguration.fontFamilyTransform] to improve font
  /// matching.
  standard,

  /// Every paragraph is drawn into a bitmap exactly as Flutter renders it on
  /// the device, regardless of its font, and sent through the image resource
  /// pipeline. The replay matches the device, including custom fonts, weights,
  /// mixed styles, ellipses and line breaks.
  ///
  /// This costs more than [standard]: each new or changed paragraph is
  /// rasterized during capture and uploaded as an image, so screens with
  /// frequently changing text (timers, counters, fast scrolling lists) upload
  /// more data.
  ///
  /// Bitmaps are limited to
  /// [DatadogSessionReplayConfiguration.maxImagePixelBudget] pixels, so very
  /// large paragraphs are rasterized at a lower resolution. This doesn't depend
  /// on [DatadogSessionReplayConfiguration.imageDownscaling].
  ///
  /// Text masked by [TextAndInputPrivacyLevel.maskAll] is sent as masked
  /// text and is never rasterized. Editable text fields are always sent as
  /// text. Widgets placed inline with [WidgetSpan] are recorded as their own
  /// nodes.
  highFidelity,
}

enum ImageDownscaling {
  /// No Dart-side resizing of decoded images before upload.
  ///
  /// If decoded width × height exceeds the configured
  /// [DatadogSessionReplayConfiguration.maxImagePixelBudget], capture uses a
  /// "Large Image" placeholder instead of uploading pixels.
  ///
  /// Decoded images within that budget are uploaded at native resolution. They
  /// are **not** shrunk to match on-screen painted size; use
  /// [ImageDownscaling.enabled] for that.
  ///
  /// Rasterized icons over the same budget use a "Large Icon" placeholder.
  disabled,

  /// Downscale decoded images in Dart when needed so they fit the painted bounds
  /// (logical size × device pixel ratio) and
  /// [DatadogSessionReplayConfiguration.maxImagePixelBudget].
  ///
  /// Rasterized icons are also drawn at a lower resolution to fit the budget.
  enabled,
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

  /// Whether to downscale decoded images before upload.
  ///
  /// [ImageDownscaling.enabled] scales images to fit painted size and
  /// [maxImagePixelBudget]. [ImageDownscaling.disabled] (the default) uploads
  /// decoded pixels at native resolution when width × height is within
  /// [maxImagePixelBudget]; if over budget, uses a "Large Image" placeholder.
  ///
  /// Also applies to icons from fonts the replay player doesn't have, which
  /// Session Replay rasterizes. Paragraphs recorded with
  /// [TextCaptureMode.highFidelity] are always drawn at a lower resolution to
  /// fit [maxImagePixelBudget], whatever this is set to.
  ImageDownscaling imageDownscaling;

  /// Maximum decoded width × height (pixels) for image uploads, including the
  /// bitmaps of paragraphs recorded with [TextCaptureMode.highFidelity] and of
  /// rasterized icons.
  ///
  /// When [imageDownscaling] is [ImageDownscaling.disabled], decoded images
  /// above this value use a "Large Image" placeholder; at or below it, native
  /// decoded pixels are uploaded without resizing to on-screen painted size.
  ///
  /// When [imageDownscaling] is [ImageDownscaling.enabled], images are
  /// downscaled as needed to meet this budget and the painted bounds.
  ///
  /// Defaults to approximately 800×800 decoded pixels. Values below 1 are
  /// ignored, with a warning, in favor of the default.
  int maxImagePixelBudget;

  /// How text widgets are recorded. See [TextCaptureMode].
  ///
  /// Defaults to [TextCaptureMode.standard].
  TextCaptureMode textCaptureMode;

  /// Whether this Flutter module is embedded inside a native host app
  /// (Flutter add-to-app). When `true`, records are handed to the native
  /// Session Replay instead of being uploaded from here, stamped with the slot
  /// ID of the host view showing this engine, so the player composites the
  /// Flutter content into the native host's embedded-content placeholder.
  ///
  /// The host must opt each Flutter view in as well — call
  /// `flutterViewController.dd.enableSessionReplay()` on iOS, or
  /// `flutterFragment.enableSessionReplay()` on Android. Records captured
  /// before it does are buffered natively, up to a couple of seconds' worth.
  ///
  /// Set to `false` (the default) when Flutter is the host application.
  bool isEmbedded;

  DatadogSessionReplayConfiguration({
    required this.replaySampleRate,
    this.textAndInputPrivacyLevel = TextAndInputPrivacyLevel.maskAll,
    this.imagePrivacyLevel = ImagePrivacyLevel.maskAll,
    this.touchPrivacyLevel = TouchPrivacyLevel.hide,
    this.customEndpoint,
    this.startRecordingImmediately = true,
    this.fontFamilyTransform = const FontFamilyTransformConfig(),
    this.imageDownscaling = ImageDownscaling.disabled,
    this.maxImagePixelBudget = defaultMaxImagePixelBudget,
    // TODO: Once Flutter session replay becomes billable, change the default to highFidelity mode.
    this.textCaptureMode = TextCaptureMode.standard,
    this.isEmbedded = false,
  });
}

extension SessionReplayExtension on DatadogConfiguration {
  void enableSessionReplay(DatadogSessionReplayConfiguration config) {
    addPlugin(DatadogSessionReplayPluginConfiguration(configuration: config));
  }
}
