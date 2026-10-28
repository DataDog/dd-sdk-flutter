// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:meta/meta.dart';

/// The platform view type `webview_flutter` uses for its WebView.
const webViewPlatformViewType = 'plugins.flutter.io/webview';

/// Maps a tracked WebView's platform identifier to its Session Replay slot ID.
class WebViewSlotRegistry {
  static final Map<int, _WebViewSlot> _slots = {};
  static final Finalizer<_WebViewSlot> _finalizer = Finalizer(_removeIfCurrent);
  static int _nextGeneration = 0;

  /// Registers [slotId] for the WebView with [webViewIdentifier] until [owner]
  /// is garbage collected.
  static void register(
    int webViewIdentifier,
    String slotId, {
    required Object owner,
  }) {
    final slot = _WebViewSlot(webViewIdentifier, slotId, _nextGeneration++);
    _slots[webViewIdentifier] = slot;
    // Re-tracking the same owner replaces its previous registration.
    _finalizer.detach(owner);
    _finalizer.attach(owner, slot, detach: owner);
  }

  static String? slotId(int webViewIdentifier) =>
      _slots[webViewIdentifier]?.slotId;

  /// Whether [slotId] belongs to a WebView that is still alive.
  static bool isRegistered(String slotId) =>
      _slots.values.any((slot) => slot.slotId == slotId);

  // Finalizers run asynchronously, possibly after the identifier was reused by
  // a newer WebView, so only remove the entry if it is still the one this owner
  // registered.
  static void _removeIfCurrent(_WebViewSlot slot) {
    if (_slots[slot.webViewIdentifier]?.generation == slot.generation) {
      _slots.remove(slot.webViewIdentifier);
    }
  }

  @visibleForTesting
  static void debugFinalize(int webViewIdentifier, {required int generation}) =>
      _removeIfCurrent(_WebViewSlot(webViewIdentifier, '', generation));

  @visibleForTesting
  static int? debugGeneration(int webViewIdentifier) =>
      _slots[webViewIdentifier]?.generation;

  @visibleForTesting
  static void debugReset() => _slots.clear();
}

@immutable
class _WebViewSlot {
  final int webViewIdentifier;
  final String slotId;
  final int generation;

  const _WebViewSlot(this.webViewIdentifier, this.slotId, this.generation);
}
