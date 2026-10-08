// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'native_directories.dart';

/// Maximum length, in bytes, of the application storage path accepted by the
/// C++ SDK (`DATADOG_MAX_APPLICATION_STORAGE_PATH_LEN`).
const int maxStoragePathLength = 511;

const _windowsInvalidChars = '<>:"/\\|?*';
final _windowsReservedName = RegExp(
  r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$',
  caseSensitive: false,
);

bool _isControl(int codeUnit) => codeUnit < 0x20 || codeUnit == 0x7F;

/// Replaces anything in [name] that isn't valid in a single directory name on
/// the target platform. Returns `null` if [name] is empty.
String? sanitizePathComponent(String name, {required bool windows}) {
  if (name.isEmpty) {
    return null;
  }
  if (name == '.' || name == '..') {
    return '_';
  }

  final buffer = StringBuffer();
  for (final unit in name.codeUnits) {
    final invalid = windows
        ? _isControl(unit) || _windowsInvalidChars.codeUnits.contains(unit)
        : unit == 0x2F || unit == 0;
    buffer.writeCharCode(invalid ? 0x5F : unit);
  }
  var result = buffer.toString();

  if (windows) {
    result = result.replaceFirstMapped(
      RegExp(r'[. ]+$'),
      (m) => '_' * m.group(0)!.length,
    );
    if (_windowsReservedName.hasMatch(result)) {
      result = '${result}_';
    }
  }
  return result;
}

/// Returns a description of why [path] can't be used as the application storage
/// path, or `null` if it can.
String? validateStoragePath(String path, {required bool windows}) {
  final context = windows ? p.windows : p.posix;

  if (path.isEmpty) {
    return 'the path is empty';
  }
  // A Windows path with a root but no drive (e.g. `\data`) is relative to the
  // current drive.
  if (!context.isAbsolute(path) ||
      (windows && const ['\\', '/'].contains(context.rootPrefix(path)))) {
    return 'the path is not absolute';
  }
  if (utf8.encode(path).length > maxStoragePathLength) {
    return 'the path is longer than $maxStoragePathLength bytes';
  }

  final parts = context.split(context.normalize(path));
  // The first part is the root (e.g. `C:\`, `\\server\share`, or `/`).
  for (final part in parts.skip(1)) {
    final sanitized = sanitizePathComponent(part, windows: windows);
    if (sanitized != part) {
      return 'the path contains an invalid directory name: "$part"';
    }
  }
  if (path.codeUnits.any((u) => u == 0 || (windows && _isControl(u)))) {
    return 'the path contains invalid characters';
  }
  return null;
}

/// Creates [path] (and any missing parents), since the C++ SDK only creates
/// directories beneath it. Returns a description of the failure, or `null` on
/// success. Never throws.
String? createStorageDirectory(String path) {
  try {
    Directory(path).createSync(recursive: true);
    return null;
  } catch (e) {
    return 'the directory could not be created ($e)';
  }
}

/// Returns an absolute path for [applicationName] inside the current user's
/// data directory, or `null` if it can't be determined. Never throws.
String? suggestDesktopDataDirectory(
  String applicationName, {
  bool? windows,
  Map<String, String>? environment,
  String? Function()? localAppData,
  String? Function()? passwdHome,
  String? currentDirectory,
}) {
  try {
    windows ??= Platform.isWindows;
    environment ??= Platform.environment;
    final context = p.Context(
      style: windows ? p.Style.windows : p.Style.posix,
      current: currentDirectory ?? Directory.current.path,
    );

    final name = sanitizePathComponent(applicationName, windows: windows);
    if (name == null) {
      return null;
    }

    final String? base;
    if (windows) {
      base =
          _nonEmpty((localAppData ?? windowsLocalAppDataDirectory)()) ??
          _nonEmpty(environment['LOCALAPPDATA']);
    } else {
      base =
          _nonEmpty(environment['XDG_DATA_HOME']) ??
          _posixHomeBase(environment, passwdHome ?? posixPasswdHomeDirectory);
    }
    if (base == null) {
      return null;
    }

    final absoluteBase = context.normalize(context.absolute(base));
    if (!context.isAbsolute(absoluteBase)) {
      return null;
    }
    final result = context.join(absoluteBase, name);
    return context.isWithin(absoluteBase, result) ? result : null;
  } catch (_) {
    return null;
  }
}

String? _posixHomeBase(
  Map<String, String> environment,
  String? Function() passwdHome,
) {
  final home = _nonEmpty(environment['HOME']) ?? _nonEmpty(passwdHome());
  return home == null ? null : p.posix.join(home, '.local', 'share');
}

String? _nonEmpty(String? value) =>
    (value == null || value.isEmpty) ? null : value;
