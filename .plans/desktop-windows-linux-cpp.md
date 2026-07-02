# Flutter Desktop: Windows & Linux via dd-sdk-cpp

## Context
Extend `datadog_flutter_plugin` to support Windows and Linux desktop by integrating [dd-sdk-cpp](https://github.com/DataDog/dd-sdk-cpp) via CMake FetchContent. Implements Logs, RUM, and Crash Reporting.

The project now uses a **federated plugin architecture** (merged in PR #1068). Each platform has its own package that `implements: datadog_flutter_plugin`. The pattern is established by the existing Android, iOS, and Web packages. This plan follows that same pattern.

**Current state:**
- `DatadogSdkPlatform.instance` defaults to `DatadogSdkNoOpPlatform()` — unknown platforms are already silent no-ops, no fallback code needed.
- `integration_test_app/windows/` scaffolding exists (from `flutter create --platforms=windows`), but no C++ plugin code has been written yet.
- dd-sdk-cpp target name (v0.4.0 develop branch) is `ddsdkcpp`.
- Known bug: `filesystem_windows.cpp` line 86 needs `::CreateDirectoryW(...)` — either submit upstream or apply a patch in CMake.

---

## 1. New Package: `datadog_flutter_plugin_desktop`

Create `packages/datadog_flutter_plugin/datadog_flutter_plugin_desktop/` with the structure:

```
datadog_flutter_plugin_desktop/
  pubspec.yaml
  lib/
    datadog_flutter_plugin_desktop.dart       # exports DatadogFlutterPluginDesktop
    src/
      datadog_sdk_method_channel.dart         # copy/share from iOS/Android
      logs/
        ddlogs_method_channel.dart
      rum/
        ddrum_method_channel.dart
  windows/
    CMakeLists.txt
    src/
      datadog_windows_plugin.h
      datadog_windows_plugin.cpp
  linux/
    CMakeLists.txt
    src/
      datadog_linux_plugin.h
      datadog_linux_plugin.cc
  example/
    pubspec.yaml
    lib/
      main.dart
  test/
    (unit tests)
```

One combined package for both desktop platforms minimizes duplication: the Dart layer is identical, and the dd-sdk-cpp integration code differs only in the Flutter plugin glue layer (`flutter_windows.h` vs GLib/`flutter_linux.h`).

---

## 2. `datadog_flutter_plugin_desktop/pubspec.yaml`

```yaml
name: datadog_flutter_plugin_desktop
description: Windows and Linux desktop implementation of the datadog_flutter_plugin package.
version: 1.0.0
repository: https://github.com/DataDog/dd-sdk-flutter

environment:
  sdk: ^3.6.0
  flutter: ">=3.27.0"

dependencies:
  flutter:
    sdk: flutter
  ffi: ^2.1.3
  datadog_flutter_plugin_platform_interface: ^1.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ">=1.0.0"
  mocktail: ^1.0.4
  plugin_platform_interface: ^2.1.8
  datadog_common_test:
    path: ../../datadog_common_test

flutter:
  plugin:
    implements: datadog_flutter_plugin
    platforms:
      windows:
        pluginClass: DatadogWindowsPlugin
        dartPluginClass: DatadogFlutterPluginDesktop
      linux:
        pluginClass: DatadogLinuxPlugin
        dartPluginClass: DatadogFlutterPluginDesktop
```

---

## 3. Dart Library (`lib/`)

**`lib/datadog_flutter_plugin_desktop.dart`**
```dart
class DatadogFlutterPluginDesktop {
  static void registerWith() {
    DatadogSdkPlatform.instance = DatadogSdkMethodChannel();
    DdLogsPlatform.instance = DdLogsMethodChannel();
    DdRumPlatform.instance = DdRumMethodChannel();
  }
}
```

**`lib/src/datadog_sdk_method_channel.dart`**, `ddlogs_method_channel.dart`, `ddrum_method_channel.dart` — copy from the iOS package (they are identical to Android's). These send method calls over `MethodChannel('datadog_sdk')`.

Future cleanup opportunity: move the shared method channel implementations to `datadog_flutter_plugin_platform_interface` to eliminate duplication across iOS, Android, and Desktop.

---

## 4. Update Main Plugin pubspec

**`packages/datadog_flutter_plugin/datadog_flutter_plugin/pubspec.yaml`** — add the new package:

```yaml
dependencies:
  # ... existing deps ...
  datadog_flutter_plugin_desktop: ^1.0.0

flutter:
  plugin:
    platforms:
      android:
        default_package: datadog_flutter_plugin_android
      ios:
        default_package: datadog_flutter_plugin_ios
      web:
        default_package: datadog_flutter_plugin_web
      windows:
        default_package: datadog_flutter_plugin_desktop
      linux:
        default_package: datadog_flutter_plugin_desktop
```

---

## 5. CMake Plugin Setup

### `windows/CMakeLists.txt`

```cmake
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "datadog_flutter_plugin_desktop")
project(${PROJECT_NAME} LANGUAGES CXX)

include(FetchContent)
FetchContent_Declare(
  dd-sdk-cpp
  GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
  GIT_TAG        develop
)
FetchContent_MakeAvailable(dd-sdk-cpp)

# Patch known Windows build bug in dd-sdk-cpp
# filesystem_windows.cpp line 86 must use ::CreateDirectoryW (not CreateDirectoryW)
# to avoid ambiguity when UNICODE is defined. Apply patch or await upstream fix.

set(PLUGIN_NAME "datadog_flutter_plugin_desktop_plugin")
add_library(${PLUGIN_NAME} SHARED
  src/datadog_windows_plugin.cpp
)
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  ddsdkcpp
)
target_include_directories(${PLUGIN_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_STANDARD 17)
```

### `linux/CMakeLists.txt`

```cmake
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "datadog_flutter_plugin_desktop")
project(${PROJECT_NAME} LANGUAGES CXX)

include(FetchContent)
FetchContent_Declare(
  dd-sdk-cpp
  GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
  GIT_TAG        develop
)
FetchContent_MakeAvailable(dd-sdk-cpp)

set(PLUGIN_NAME "datadog_flutter_plugin_desktop_plugin")
add_library(${PLUGIN_NAME} SHARED
  src/datadog_linux_plugin.cc
)
target_link_libraries(${PLUGIN_NAME} PRIVATE
  PkgConfig::GTK
  flutter_linux_gtk
  ddsdkcpp
)
target_include_directories(${PLUGIN_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_STANDARD 17)
```

---

## 6. Native Plugin Entry Points

### Windows — `windows/src/datadog_windows_plugin.{h,cpp}`
- Extends `flutter::Plugin`, registers on `flutter::MethodChannel` named `"datadog_sdk"`
- Handles method calls: `initialize`, `flushAndDeinitialize`, `setSdkVerbosity`, `setUserInfo`, `clearUserInfo`, `addUserExtraInfo`, `setAccountInfo`, `clearAccountInfo`, `addAccountExtraInfo`, `setTrackingConsent`, `clearAllData`, `sendTelemetryDebug`, `sendTelemetryError`, `updateTelemetryConfiguration`, `flush`
- Logs: `createLogger`, `log`, `addLoggerAttribute`, `removeLoggerAttribute`, `addLoggerTag`, `removeLoggerTag`  
- RUM: `initializeRum`, `startView`, `stopView`, `addTiming`, `startAction`, `stopAction`, `addAction`, `startResource`, `stopResource`, `stopResourceWithError`, `addError`, `addAttribute`, `removeAttribute`, `stopSession`
- Calls into dd-sdk-cpp using the v0.4.0 API (see memory for API changes from v0.2.0)

### Linux — `linux/src/datadog_linux_plugin.{h,cc}`
- Follows Flutter Linux GLib-style plugin conventions (`FlMethodChannel`)
- Same method call surface as Windows
- Use `fl_method_channel_new` / `FL_METHOD_CHANNEL` pattern

---

## 7. Example App and Integration Test App

### New package example (`datadog_flutter_plugin_desktop/example/`)

```sh
# From the new package directory:
flutter create --platforms=windows,linux .
```

Verify the app initializes the SDK and sends a log event on each platform.

### Integration Test App

`integration_test_app/windows/` scaffolding already exists. Once the desktop package is wired up (via `default_package` in the main plugin), running:

```sh
flutter run -d windows
```

from `integration_test_app/` should pick up the plugin automatically via the federated resolution.

The existing integration tests in `integration_test_app/integration_test/` should run unmodified on Windows/Linux — they exercise the Dart SDK layer, which routes through the same method channel interface.

---

## 8. README & CONTRIBUTING

**README.md**: Add Windows and Linux to supported-platforms table; note any feature gaps vs iOS/Android at initial launch.

**CONTRIBUTING.md**:
- **Prerequisites**: Same compiler/CMake requirements as Flutter desktop — refer readers to [Flutter Windows setup](https://docs.flutter.dev/get-started/install/windows/desktop) and [Flutter Linux setup](https://docs.flutter.dev/get-started/install/linux/desktop).
- **Windows**: Developer Mode must be enabled. First build is slow (FetchContent clones dd-sdk-cpp); subsequent builds use CMake's cache.
- **Known issue**: If the Windows build fails with `CreateDirectoryW` ambiguity, re-apply the `::CreateDirectoryW` patch in `_deps/dd-sdk-cpp-src/src/datadog/common/filesystem_windows.cpp:86`. A PR to fix this upstream is the correct long-term fix.
- `flutter run -d windows` / `flutter run -d linux` from the `datadog_flutter_plugin_desktop/example/` dir.

---

## Verification

1. `flutter analyze` passes in `datadog_flutter_plugin_desktop/` and `datadog_flutter_plugin/`.
2. `flutter test` passes across the monorepo (no regressions).
3. `flutter run -d windows` in the example app — SDK initializes, log event and RUM view reach Datadog.
4. `flutter run -d linux` in the example app — same.
5. Integration tests pass on Windows: `flutter test integration_test/` from `integration_test_app/`.

---

## Unresolved Questions

- **filesystem_windows.cpp patch**: Should we apply the `::CreateDirectoryW` patch automatically via CMake `add_custom_command` / `patch`, or submit upstream first? Upstream PR preferred.
- **Linux system libraries**: Does dd-sdk-cpp require libraries beyond Flutter's Linux prerequisites (GTK, etc.)? Check upstream `CMakeLists.txt` for Linux deps.
- **Crash reporting**: Does dd-sdk-cpp support crash reporting on both Windows and Linux? If so, what API does it expose?
- **Method channel deduplication**: The `DatadogSdkMethodChannel` / `DdLogsMethodChannel` / `DdRumMethodChannel` Dart files are identical across iOS, Android, and Desktop. Should these be moved to `datadog_flutter_plugin_platform_interface` before or after the desktop package is created?
- **Release pinning**: dd-sdk-cpp is pinned to `develop` during development. A separate plan covers pinning to a release tag before shipping.
- **macOS**: Not in scope for this plan. Since `DatadogSdkPlatform.instance` defaults to `DatadogSdkNoOpPlatform()`, macOS will silently no-op until a `datadog_flutter_plugin_macos` package is created.
