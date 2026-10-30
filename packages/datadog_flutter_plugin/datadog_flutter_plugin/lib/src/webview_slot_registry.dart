// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:meta/meta.dart';

/// The platform view type `webview_flutter` uses for its WebView.
const webViewPlatformViewType = 'plugins.flutter.io/webview';

/// Maps a tracked WebView's platform identifier to its Session Replay slot ID.
class WebViewSlotRegistry {
  static WebViewSlotRegistry _instance = WebViewSlotRegistry();

  /// The registry WebView tracking and Session Replay share.
  static WebViewSlotRegistry get instance => _instance;

  @visibleForTesting
  static set instance(WebViewSlotRegistry value) => _instance = value;

  final Map<int, _WebViewSlot> _slots = {};
  late final Finalizer<_WebViewSlot> _finalizer = Finalizer(
    (slot) => removeIfCurrent(slot.webViewIdentifier, slot.registrationId),
  );
  int _nextRegistrationId = 0;

  /// Registers [slotId] for the WebView with [webViewIdentifier] until [owner]
  /// is garbage collected.
  void register(int webViewIdentifier, String slotId, {required Object owner}) {
    final slot = _WebViewSlot(webViewIdentifier, slotId, _nextRegistrationId++);
    _slots[webViewIdentifier] = slot;
    // Re-tracking the same owner replaces its previous registration.
    _finalizer.detach(owner);
    _finalizer.attach(owner, slot, detach: owner);
  }

  String? slotId(int webViewIdentifier) => _slots[webViewIdentifier]?.slotId;

  /// Whether [slotId] belongs to a WebView that is still alive.
  bool isRegistered(String slotId) =>
      _slots.values.any((slot) => slot.slotId == slotId);

  // Finalizers run asynchronously, possibly after the identifier was reused by
  // a newer WebView, so only remove the entry if it is still the one this owner
  // registered.
  @visibleForTesting
  void removeIfCurrent(int webViewIdentifier, int registrationId) {
    if (_slots[webViewIdentifier]?.registrationId == registrationId) {
      _slots.remove(webViewIdentifier);
    }
  }

  @visibleForTesting
  int? debugRegistrationId(int webViewIdentifier) =>
      _slots[webViewIdentifier]?.registrationId;
}

@immutable
class _WebViewSlot {
  final int webViewIdentifier;
  final String slotId;
  final int registrationId;

  const _WebViewSlot(this.webViewIdentifier, this.slotId, this.registrationId);
}
