// Unless otherwise stated, all files in this repository are licensed under
// the Apache License Version 2.0. This product includes software developed
// at Datadog (https://www.datadoghq.com/). Copyright 2025-Present Datadog, Inc.

import 'package:meta/meta.dart';

import '../../datadog_session_replay.dart'
    show FontFamilyStrategy, FontFamilyTransformConfig;
import '../sr_data_models.dart';

/// Default CSS font stack for the replay player, aligned with both native SDKs
/// (iOS: `-apple-system, BlinkMacSystemFont, 'Roboto', sans-serif`;
///  Android: `Roboto, sans-serif`).
/// Uses `Roboto` instead of `'Roboto'` so smart-mode round-trip matches
/// [formatFamilyForCssList].
@visibleForTesting
const String defaultReplayFontStack =
    '-apple-system, BlinkMacSystemFont, Roboto, sans-serif';

/// Resolved font-family strings Flutter uses for the platform UI font that are
/// not valid CSS `font-family` tokens in the replay player. Tokens matching
/// these are dropped in [FontFamilyStrategy.smart] so only web-usable names
/// remain (or the iOS-parity stack when nothing is left).
const Set<String> _flutterFontSentinels = {
  'CupertinoSystemText',
  'CupertinoSystemDisplay',
  '.SF UI Text',
  '.SF UI Display',
  '.AppleSystemUIFont',
};

/// Standard and webview font keywords (lowercased) that count as a generic
/// CSS fallback and block appending an extra [sans-serif](lowercase).
const Set<String> _genericFamilyLower = {
  'serif',
  'sans-serif',
  'monospace',
  'system-ui',
  'cursive',
  'fantasy',
  '-apple-system',
  'blinkmacsystemfont',
};

/// Strips a `packages/<packageName>/` prefix from pub/bundled font family
/// names.
@visibleForTesting
String stripPackageFontPrefix(String name) {
  if (name.isEmpty) {
    return name;
  }
  const prefix = 'packages/';
  if (!name.startsWith(prefix)) {
    return name;
  }
  final firstSlash = name.indexOf('/', prefix.length);
  if (firstSlash < 0) {
    return name;
  }
  return name.substring(firstSlash + 1);
}

@visibleForTesting
String peelOuterQuotes(String s) {
  var t = s.trim();
  while (t.length >= 2) {
    final a = t.codeUnitAt(0);
    final b = t.codeUnitAt(t.length - 1);
    if (a == 0x27 && b == 0x27) {
      t = t.substring(1, t.length - 1).trim();
    } else if (a == 0x22 && b == 0x22) {
      t = t.substring(1, t.length - 1).trim();
    } else {
      break;
    }
  }
  return t;
}

@visibleForTesting
String formatFamilyForCssList(String name) {
  if (name.isEmpty) {
    return name;
  }
  final lower = name.toLowerCase();
  if (_genericFamilyLower.contains(lower)) {
    return switch (lower) {
      'blinkmacsystemfont' => 'BlinkMacSystemFont',
      '-apple-system' => '-apple-system',
      _ => lower,
    };
  }
  if (name.contains(' ')) {
    return "'${name.replaceAll("'", r"\'")}'";
  }
  return name;
}

bool _hasGenericFamily(List<String> tokens) {
  for (final t in tokens) {
    if (_genericFamilyLower.contains(peelOuterQuotes(t).toLowerCase())) {
      return true;
    }
  }
  return false;
}

/// Comma-split family tokens after trim and outer-quote peel; used for rule
/// values and parsing [FontFamilyTransformConfig.rules] empty-key fallback.
List<String> _familyTokensFromCommaList(String source) {
  final out = <String>[];
  for (final part in source.split(',')) {
    final p = peelOuterQuotes(part);
    if (p.isNotEmpty) {
      out.add(p);
    }
  }
  return out;
}

/// Rewrites captured Flutter font family strings for web replay.
class FontFamilyTransform {
  FontFamilyTransform(this.config);

  final FontFamilyTransformConfig config;

  String transformFamily(String captured) {
    switch (config.strategy) {
      case FontFamilyStrategy.none:
        return captured;
      case FontFamilyStrategy.fallback:
        return defaultReplayFontStack;
      case FontFamilyStrategy.smart:
        return _applySmart(captured);
    }
  }

  SRTextWireframe apply(SRTextWireframe wireframe) {
    final nextFamily = transformFamily(wireframe.textStyle.family);
    if (nextFamily == wireframe.textStyle.family) {
      return wireframe;
    }
    return SRTextWireframe(
      id: wireframe.id,
      x: wireframe.x,
      y: wireframe.y,
      width: wireframe.width,
      height: wireframe.height,
      text: wireframe.text,
      textStyle: SRTextStyle(
        color: wireframe.textStyle.color,
        family: nextFamily,
        size: wireframe.textStyle.size,
      ),
      border: wireframe.border,
      clip: wireframe.clip,
      shapeStyle: wireframe.shapeStyle,
      textPosition: wireframe.textPosition,
    );
  }

  String _applySmart(String captured) {
    if (captured.trim().isEmpty) {
      return _emptyFamilyFallback();
    }

    final rawTokens = captured.split(',');
    final expanded = <String>[];

    for (final raw in rawTokens) {
      final peeled = peelOuterQuotes(raw);
      if (peeled.isEmpty) {
        continue;
      }

      final stripped = stripPackageFontPrefix(peeled);
      if (stripped.isEmpty) {
        continue;
      }

      final replacement = config.rules[peeled] ?? config.rules[stripped];
      if (replacement != null) {
        expanded.addAll(_familyTokensFromCommaList(replacement));
        continue;
      }

      if (_flutterFontSentinels.contains(stripped)) {
        continue;
      }

      expanded.add(stripped);
    }

    if (expanded.isEmpty) {
      return _emptyFamilyFallback();
    }

    return _joinFormattedFamilyStack(expanded);
  }

  /// Appends a generic keyword when needed and formats for CSS `font-family`.
  String _joinFormattedFamilyStack(List<String> expanded) {
    var working = List<String>.from(expanded);
    if (!_hasGenericFamily(working)) {
      working.add('sans-serif');
    }
    return working.map(formatFamilyForCssList).join(', ');
  }

  /// When the captured family is empty or no usable tokens remain, honor the
  /// [FontFamilyTransformConfig.rules] entry whose key is the empty string if
  /// set; otherwise the iOS-parity stack.
  String _emptyFamilyFallback() {
    final custom = config.rules[''];
    if (custom != null && custom.trim().isNotEmpty) {
      final expanded = _familyTokensFromCommaList(custom);
      if (expanded.isEmpty) {
        return defaultReplayFontStack;
      }
      return _joinFormattedFamilyStack(expanded);
    }
    return defaultReplayFontStack;
  }
}
