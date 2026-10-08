// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

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

final class _Passwd extends ffi.Struct {
  external ffi.Pointer<Utf8> pwName;
  external ffi.Pointer<Utf8> pwPasswd;
  @ffi.Uint32()
  external int pwUid;
  @ffi.Uint32()
  external int pwGid;
  external ffi.Pointer<Utf8> pwGecos;
  external ffi.Pointer<Utf8> pwDir;
  external ffi.Pointer<Utf8> pwShell;
}

typedef _GetUidNative = ffi.Uint32 Function();
typedef _GetUidDart = int Function();
typedef _GetPwUidNative = ffi.Pointer<_Passwd> Function(ffi.Uint32);
typedef _GetPwUidDart = ffi.Pointer<_Passwd> Function(int);

/// Returns the current user's home directory from the password database, or
/// `null` if it can't be determined. [_Passwd] matches the Linux layout, so
/// this returns `null` on other platforms.
String? posixPasswdHomeDirectory() {
  if (!Platform.isLinux) {
    return null;
  }
  try {
    final libc = ffi.DynamicLibrary.process();
    final getuid = libc.lookupFunction<_GetUidNative, _GetUidDart>('getuid');
    final getpwuid = libc.lookupFunction<_GetPwUidNative, _GetPwUidDart>(
      'getpwuid',
    );

    final entry = getpwuid(getuid());
    if (entry == ffi.nullptr || entry.ref.pwDir == ffi.nullptr) {
      return null;
    }
    return entry.ref.pwDir.toDartString();
  } catch (_) {
    return null;
  }
}
