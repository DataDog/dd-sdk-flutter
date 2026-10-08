// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

/// Maximum length, in bytes, of the application storage path accepted by the
/// C++ SDK (`DATADOG_MAX_APPLICATION_STORAGE_PATH_LEN`).
const int maxStoragePathLength = 511;

/// Maximum length, in bytes, of a single directory name accepted by common
/// filesystems (NTFS, ext4, APFS).
const int maxPathComponentLength = 255;

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
/// data directory, or `null` if it can't be determined or the result couldn't
/// be used as a storage path. Never throws.
String? suggestDesktopDataDirectory(
  String applicationName, {
  bool? windows,
  Map<String, String>? environment,
  String? Function()? localAppData,
}) {
  try {
    windows ??= Platform.isWindows;
    environment ??= Platform.environment;
    final context = windows ? p.windows : p.posix;

    final name = sanitizePathComponent(applicationName, windows: windows);
    if (name == null || utf8.encode(name).length > maxPathComponentLength) {
      return null;
    }

    final String? base;
    if (windows) {
      base =
          _nonEmpty((localAppData ?? windowsLocalAppDataDirectory)()) ??
          _nonEmpty(environment['LOCALAPPDATA']);
    } else {
      // The XDG spec says relative paths in these variables must be ignored.
      final xdgDataHome = _nonEmpty(environment['XDG_DATA_HOME']);
      final home = _nonEmpty(environment['HOME']);
      base = xdgDataHome != null && context.isAbsolute(xdgDataHome)
          ? xdgDataHome
          : home == null
          ? null
          : context.join(home, '.local', 'share');
    }
    // Never anchor to the working directory, which is the development-only
    // location this helper exists to avoid.
    if (base == null || !context.isAbsolute(base)) {
      return null;
    }

    final result = context.join(context.normalize(base), name);
    if (!context.isWithin(base, result) ||
        validateStoragePath(result, windows: windows) != null) {
      return null;
    }
    return result;
  } catch (_) {
    return null;
  }
}

String? _nonEmpty(String? value) =>
    (value == null || value.isEmpty) ? null : value;

// FOLDERID_LocalAppData {F1B32785-6FBA-4FCF-9D55-7B8E7F157091}
final class _Guid extends ffi.Struct {
  @ffi.Uint32()
  external int data1;
  @ffi.Uint16()
  external int data2;
  @ffi.Uint16()
  external int data3;
  @ffi.Array(8)
  external ffi.Array<ffi.Uint8> data4;
}

typedef _GetKnownFolderPathNative =
    ffi.Int32 Function(
      ffi.Pointer<_Guid>,
      ffi.Uint32,
      ffi.IntPtr,
      ffi.Pointer<ffi.Pointer<Utf16>>,
    );
typedef _GetKnownFolderPathDart =
    int Function(ffi.Pointer<_Guid>, int, int, ffi.Pointer<ffi.Pointer<Utf16>>);

typedef _CoTaskMemFreeNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _CoTaskMemFreeDart = void Function(ffi.Pointer<ffi.Void>);

/// Returns the current user's local application data folder (the value of
/// `FOLDERID_LocalAppData`), or `null` if it can't be determined.
String? windowsLocalAppDataDirectory() {
  try {
    final shell32 = ffi.DynamicLibrary.open('shell32.dll');
    final ole32 = ffi.DynamicLibrary.open('ole32.dll');
    final getKnownFolderPath = shell32
        .lookupFunction<_GetKnownFolderPathNative, _GetKnownFolderPathDart>(
          'SHGetKnownFolderPath',
        );
    final coTaskMemFree = ole32
        .lookupFunction<_CoTaskMemFreeNative, _CoTaskMemFreeDart>(
          'CoTaskMemFree',
        );

    return using((arena) {
      final folderId = arena<_Guid>();
      folderId.ref.data1 = 0xF1B32785;
      folderId.ref.data2 = 0x6FBA;
      folderId.ref.data3 = 0x4FCF;
      const data4 = [0x9D, 0x55, 0x7B, 0x8E, 0x7F, 0x15, 0x70, 0x91];
      for (var i = 0; i < data4.length; ++i) {
        folderId.ref.data4[i] = data4[i];
      }

      final outPath = arena<ffi.Pointer<Utf16>>();
      final result = getKnownFolderPath(folderId, 0, 0, outPath);
      final pathPtr = outPath.value;
      try {
        if (result != 0 || pathPtr == ffi.nullptr) {
          return null;
        }
        return pathPtr.toDartString();
      } finally {
        // The shell allocates the buffer even on some failures.
        if (pathPtr != ffi.nullptr) {
          coTaskMemFree(pathPtr.cast());
        }
      }
    });
  } catch (_) {
    return null;
  }
}
