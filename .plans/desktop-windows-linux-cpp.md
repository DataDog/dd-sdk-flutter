# Flutter Desktop: Windows & Linux via dd-sdk-cpp

## Context
Extend `datadog_flutter_plugin` to support Windows and Linux desktop by integrating [dd-sdk-cpp](https://github.com/DataDog/dd-sdk-cpp) via CMake FetchContent. Implements Logs, RUM, and Crash Reporting. The existing `DatadogSdkMethodChannel` Dart class sends method channel calls — the only missing piece is native C++ code to receive them. The C++ SDK is pinned to `develop` during development; a separate plan covers release pinning.

---

## 1. Unknown-Platform Fallback (Dart)

Currently, calling the plugin on an unsupported platform produces a `MissingPluginException`. Instead:
- In `DatadogSdk.initialize()` (or `DatadogSdkMethodChannel`), catch `MissingPluginException` and fall back to `DatadogSdkNoOpPlatform` silently.
- The no-op already exists in `lib/src/datadog_noop_platform.dart`. This covers any future unknown platform without throwing.

---

## 2. CMake Plugin Setup (per platform)

**`packages/datadog_flutter_plugin/windows/CMakeLists.txt`** and **`linux/CMakeLists.txt`** — each must:

1. Pull dd-sdk-cpp via FetchContent pinned to `develop`:
   ```cmake
   include(FetchContent)
   FetchContent_Declare(
     dd-sdk-cpp
     GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
     GIT_TAG        develop
   )
   FetchContent_MakeAvailable(dd-sdk-cpp)
   ```
2. Define the plugin shared library, link against dd-sdk-cpp's CMake target (name TBD — check upstream `CMakeLists.txt`).
3. Follow Flutter's CMake plugin conventions (register plugin class, link `flutter_windows`/`flutter_linux`).

---

## 3. Native Plugin Entry Points

### Windows — `windows/src/datadog_windows_plugin.{h,cpp}`
- Extends `flutter::Plugin`, registers on `MethodChannel("datadog_sdk")`
- Handles method calls: `initialize`, `flushAndDeinitialize`, `log`, `startView`, `stopView`, `addError`, etc.
- Calls into dd-sdk-cpp for SDK operations (specific API TBD from upstream headers).

### Linux — `linux/src/datadog_linux_plugin.{h,cc}`
- Follows Flutter Linux GLib-style plugin conventions (`FlMethodChannel`)
- Same method call surface as Windows.

---

## 4. pubspec.yaml

Add to `packages/datadog_flutter_plugin/pubspec.yaml` under `flutter.plugin.platforms`:
```yaml
windows:
  pluginClass: DatadogWindowsPlugin
linux:
  pluginClass: DatadogLinuxPlugin
```

---

## 5. Example App

Scaffold platform dirs in `packages/datadog_flutter_plugin/example/`:
```
flutter create --platforms=windows,linux .
```
Verify the example app initializes the SDK and sends a log/RUM event on each platform.

---

## 6. README & CONTRIBUTING

**README.md**: Add Windows and Linux to supported-platforms table; note any feature gaps vs iOS/Android at initial launch.

**CONTRIBUTING.md**:
- **Prerequisites**: Same compiler/CMake requirements as Flutter desktop itself — refer readers to [Flutter Windows setup](https://docs.flutter.dev/get-started/install/windows/desktop) and [Flutter Linux setup](https://docs.flutter.dev/get-started/install/linux/desktop). No additional tooling beyond what Flutter desktop already requires.
- Note that the first build will be slow (FetchContent clones dd-sdk-cpp); subsequent builds are cached.
- `flutter run -d windows` / `flutter run -d linux` from the example dir.

---

## Verification

1. Flutter and Dart linting pass with no warnings (`flutter analyze`).
2. `flutter test` passes (unknown-platform fallback doesn't break existing tests).
3. Integration tests pass on both Windows and Linux (`flutter test integration_test/` in `integration_test_app/`).
4. `flutter run -d windows` in example — SDK initializes, log event reaches Datadog.
5. `flutter run -d linux` in example — same.

---

## Unresolved Questions

- What is the CMake target name exported by dd-sdk-cpp? (Check upstream `CMakeLists.txt`.)
- Does dd-sdk-cpp require system libraries on Linux beyond Flutter's own prerequisites?
- Does dd-sdk-cpp support crash reporting on both Windows and Linux?
- Full method surface mapping: which existing method channel calls map to which dd-sdk-cpp APIs?
