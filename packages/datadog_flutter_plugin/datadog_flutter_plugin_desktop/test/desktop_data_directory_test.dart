// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:datadog_flutter_plugin_desktop/src/desktop_data_directory.dart';
import 'package:flutter_test/flutter_test.dart';

/// A literal backslash, spelled out to avoid escaping noise in Windows paths.
final _bs = String.fromCharCode(0x5C);

/// A CJK character: 3 UTF-8 bytes, 1 UTF-16 code unit.
final _cjk = String.fromCharCode(0x4E2D);

/// A character outside the BMP: 4 UTF-8 bytes, 2 UTF-16 code units.
final _astral = String.fromCharCode(0x1D11E);

void main() {
  group('sanitizePathComponent', () {
    test('returns null for an empty name', () {
      expect(sanitizePathComponent('', windows: true), isNull);
      expect(sanitizePathComponent('', windows: false), isNull);
    });

    test('keeps dots inside a name', () {
      for (final windows in [true, false]) {
        expect(
          sanitizePathComponent('com.datadoghq.app', windows: windows),
          'com.datadoghq.app',
        );
        expect(sanitizePathComponent('.hidden', windows: windows), '.hidden');
      }
    });

    test('replaces "." and ".." on both platforms', () {
      for (final windows in [true, false]) {
        expect(sanitizePathComponent('.', windows: windows), '_');
        expect(sanitizePathComponent('..', windows: windows), '_');
      }
    });

    test('replaces invalid characters on Windows', () {
      expect(
        sanitizePathComponent('a<b>c:d"e/f\\g|h?i*j', windows: true),
        'a_b_c_d_e_f_g_h_i_j',
      );
      expect(sanitizePathComponent('a\u0001b', windows: true), 'a_b');
    });

    test('replaces trailing dots and spaces on Windows only', () {
      expect(sanitizePathComponent('app. .', windows: true), 'app___');
      expect(sanitizePathComponent('app.', windows: false), 'app.');
    });

    test('suffixes reserved names on Windows', () {
      expect(sanitizePathComponent('CON', windows: true), 'CON_');
      expect(sanitizePathComponent('com1', windows: true), 'com1_');
      expect(sanitizePathComponent('nul.txt', windows: true), 'nul.txt_');
      expect(sanitizePathComponent('CONSOLE', windows: true), 'CONSOLE');
      expect(sanitizePathComponent('CON', windows: false), 'CON');
    });

    test('replaces only separators and NUL on Linux', () {
      expect(sanitizePathComponent('a/b\u0000c', windows: false), 'a_b_c');
      expect(sanitizePathComponent('a<b>:"|?*', windows: false), 'a<b>:"|?*');
    });
  });

  group('validateStoragePath', () {
    test('accepts valid absolute paths', () {
      expect(
        validateStoragePath('/home/me/.local/share/app', windows: false),
        isNull,
      );
      expect(
        validateStoragePath('C:\\Users\\me\\AppData\\app', windows: true),
        isNull,
      );
      expect(validateStoragePath('C:/Users/me/app', windows: true), isNull);
      expect(
        validateStoragePath('\\\\server\\share\\app', windows: true),
        isNull,
      );
    });

    test('rejects empty paths', () {
      expect(validateStoragePath('', windows: false), isNotNull);
      expect(validateStoragePath('', windows: true), isNotNull);
    });

    test('rejects relative paths', () {
      expect(validateStoragePath('data/app', windows: false), isNotNull);
      expect(validateStoragePath('.', windows: false), isNotNull);
      expect(validateStoragePath('app', windows: true), isNotNull);
      expect(validateStoragePath('C:app', windows: true), isNotNull);
      expect(validateStoragePath('\\app', windows: true), isNotNull);
    });

    test('rejects invalid names on Windows', () {
      expect(validateStoragePath('C:\\data\\a?b', windows: true), isNotNull);
      expect(validateStoragePath('C:\\data\\CON', windows: true), isNotNull);
      expect(validateStoragePath('C:\\data\\app.', windows: true), isNotNull);
    });

    test('allows characters that are only invalid on Windows on Linux', () {
      expect(validateStoragePath('/data/a?b', windows: false), isNull);
      expect(validateStoragePath('/data/app.', windows: false), isNull);
    });

    test('rejects NUL', () {
      expect(validateStoragePath('/data/a\u0000b', windows: false), isNotNull);
    });

    test('rejects paths longer than the SDK limit', () {
      // Segments stay under the per-name limit; only the total length varies.
      String pathOfLength(int length) =>
          '/${'a' * 200}/${'a' * 200}/${'a' * (length - 403)}';
      final ok = pathOfLength(maxStoragePathLength);
      final tooLong = pathOfLength(maxStoragePathLength + 1);
      expect(utf8.encode(ok).length, maxStoragePathLength);
      expect(validateStoragePath(ok, windows: false), isNull);
      expect(validateStoragePath(tooLong, windows: false), isNotNull);
    });

    test('counts length in bytes', () {
      // Each 'é' is two bytes in UTF-8.
      final segment = 'é' * 100;
      final tooLong = '/$segment/$segment/$segment';
      expect(tooLong.length, lessThan(maxStoragePathLength));
      expect(validateStoragePath(tooLong, windows: false), isNotNull);
    });

    test('rejects directory names that are too long for the platform', () {
      final longName = 'a' * (maxPathComponentLength + 1);
      expect(
        validateStoragePath('/home/me/$longName', windows: false),
        contains('longer than'),
      );
      expect(
        validateStoragePath(['C:', 'Users', longName].join(_bs), windows: true),
        contains('longer than'),
      );
    });

    test('measures directory name length per platform', () {
      final cjkName = _cjk * 100; // 300 UTF-8 bytes, 100 UTF-16 units
      expect(
        validateStoragePath('/home/me/$cjkName', windows: false),
        contains('longer than'),
      );
      expect(
        validateStoragePath(['C:', 'Users', cjkName].join(_bs), windows: true),
        isNull,
      );
    });
  });

  group('suggestDesktopDataDirectory', () {
    test('uses XDG_DATA_HOME on Linux', () {
      expect(
        suggestDesktopDataDirectory(
          'myapp',
          windows: false,
          environment: {'XDG_DATA_HOME': '/xdg', 'HOME': '/home/me'},
        ),
        '/xdg/myapp',
      );
    });

    test('falls back to HOME on Linux', () {
      expect(
        suggestDesktopDataDirectory(
          'myapp',
          windows: false,
          environment: {'HOME': '/home/me'},
        ),
        '/home/me/.local/share/myapp',
      );
    });

    test('ignores empty environment variables on Linux', () {
      expect(
        suggestDesktopDataDirectory(
          'myapp',
          windows: false,
          environment: {'XDG_DATA_HOME': '', 'HOME': '/home/me'},
        ),
        '/home/me/.local/share/myapp',
      );
    });

    test('returns null on Linux when HOME is not set', () {
      expect(
        suggestDesktopDataDirectory('myapp', windows: false, environment: {}),
        isNull,
      );
    });

    test('returns null on Linux when HOME is relative', () {
      expect(
        suggestDesktopDataDirectory(
          'myapp',
          windows: false,
          environment: {'HOME': 'relative/home'},
        ),
        isNull,
      );
    });

    test('ignores a relative XDG_DATA_HOME on Linux', () {
      expect(
        suggestDesktopDataDirectory(
          'myapp',
          windows: false,
          environment: {'XDG_DATA_HOME': 'relative/data', 'HOME': '/home/me'},
        ),
        '/home/me/.local/share/myapp',
      );
    });

    test('returns null on Linux for a relative XDG_DATA_HOME without HOME', () {
      expect(
        suggestDesktopDataDirectory(
          'myapp',
          windows: false,
          environment: {'XDG_DATA_HOME': 'relative/data'},
        ),
        isNull,
      );
    });

    test('returns null on Windows for a relative LOCALAPPDATA', () {
      expect(
        suggestDesktopDataDirectory(
          'myapp',
          windows: true,
          environment: {
            'LOCALAPPDATA': ['relative', 'data'].join(_bs),
          },
          localAppData: () => null,
        ),
        isNull,
      );
    });

    test('limits the application name component to 255 bytes on Linux', () {
      final env = {'HOME': '/home/me'};
      expect(
        suggestDesktopDataDirectory(
          'a' * maxPathComponentLength,
          windows: false,
          environment: env,
        ),
        isNotNull,
      );
      expect(
        suggestDesktopDataDirectory(
          'a' * (maxPathComponentLength + 1),
          windows: false,
          environment: env,
        ),
        isNull,
      );
      // 100 CJK characters are 300 UTF-8 bytes.
      expect(
        suggestDesktopDataDirectory(
          _cjk * 100,
          windows: false,
          environment: env,
        ),
        isNull,
      );
    });

    test('limits the application name component to 255 UTF-16 units on '
        'Windows', () {
      String? suggest(String name) => suggestDesktopDataDirectory(
        name,
        windows: true,
        environment: {},
        localAppData: () => 'C:$_bs', // A drive root leaves the most room.
      );
      expect(suggest('a' * maxPathComponentLength), isNotNull);
      expect(suggest('a' * (maxPathComponentLength + 1)), isNull);
      // 100 CJK characters are 100 UTF-16 units, so they fit on NTFS.
      expect(suggest(_cjk * 100), isNotNull);
      // Characters outside the BMP are two UTF-16 units each.
      expect(suggest(_astral * 127), isNotNull);
      expect(suggest(_astral * 128), isNull);
    });

    test('returns null when the result is longer than the SDK limit', () {
      final longHome = '/${'a' * 200}/${'b' * 200}';
      expect(
        suggestDesktopDataDirectory(
          'c' * 150,
          windows: false,
          environment: {'HOME': longHome},
        ),
        isNull,
      );
      expect(
        suggestDesktopDataDirectory(
          'myapp',
          windows: false,
          environment: {'HOME': longHome},
        ),
        isNotNull,
      );
    });

    test('only returns paths that pass validateStoragePath', () {
      final result = suggestDesktopDataDirectory(
        'com.datadoghq.app',
        windows: true,
        environment: {},
        localAppData: () => ['C:', 'Users', 'me', 'AppData', 'Local'].join(_bs),
      );
      expect(validateStoragePath(result!, windows: true), isNull);
    });

    test('uses the known folder on Windows', () {
      expect(
        suggestDesktopDataDirectory(
          'myapp',
          windows: true,
          environment: {'LOCALAPPDATA': 'C:\\env'},
          localAppData: () => 'C:\\Users\\me\\AppData\\Local',
        ),
        'C:\\Users\\me\\AppData\\Local\\myapp',
      );
    });

    test('falls back to LOCALAPPDATA on Windows', () {
      expect(
        suggestDesktopDataDirectory(
          'myapp',
          windows: true,
          environment: {'LOCALAPPDATA': 'C:\\env'},
          localAppData: () => null,
        ),
        'C:\\env\\myapp',
      );
    });

    test('returns null on Windows when no location can be found', () {
      expect(
        suggestDesktopDataDirectory(
          'myapp',
          windows: true,
          environment: {},
          localAppData: () => null,
        ),
        isNull,
      );
    });

    test('returns null for an empty application name', () {
      expect(
        suggestDesktopDataDirectory(
          '',
          windows: false,
          environment: {'HOME': '/home/me'},
        ),
        isNull,
      );
    });

    test('keeps the result inside the base directory', () {
      for (final name in ['..', '.', '../../etc', 'a/../..']) {
        final result = suggestDesktopDataDirectory(
          name,
          windows: false,
          environment: {'HOME': '/home/me'},
        );
        expect(result, startsWith('/home/me/.local/share/'));
        expect(result!.split('/'), isNot(contains('..')));
        expect(result.split('/'), hasLength(6));
      }
    });

    test('does not throw when a lookup throws', () {
      expect(
        suggestDesktopDataDirectory(
          'myapp',
          windows: true,
          environment: {},
          localAppData: () => throw StateError('boom'),
        ),
        isNull,
      );
    });
  });

  group('createStorageDirectory', () {
    late Directory temp;
    setUp(() => temp = Directory.systemTemp.createTempSync('dd_dir_test'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('creates missing parent directories', () {
      final path =
          '${temp.path}${Platform.pathSeparator}a'
          '${Platform.pathSeparator}b';
      expect(createStorageDirectory(path), isNull);
      expect(Directory(path).existsSync(), isTrue);
    });

    test('succeeds when the directory already exists', () {
      expect(createStorageDirectory(temp.path), isNull);
    });

    test('returns an error instead of throwing when a file is in the way', () {
      final file = File('${temp.path}${Platform.pathSeparator}f')
        ..writeAsStringSync('x');
      expect(createStorageDirectory(file.path), isNotNull);
    });
  });

  group('native lookups', () {
    test('Windows local app data directory is absolute', () {
      final dir = windowsLocalAppDataDirectory();
      expect(dir, isNotNull);
      expect(validateStoragePath(dir!, windows: true), isNull);
    }, skip: Platform.isWindows ? false : 'Windows only');
  });
}
