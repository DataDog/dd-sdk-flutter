# Changelog

## 1.0.0-preview.1

### Features

- Initial release of `datadog_flutter_plugin_android` as a standalone federated plugin package providing the Android platform implementation of the Datadog Flutter Plugin, enabling Android-specific fixes and releases independent of other platforms.
- Configuring the Datadog SDK now requires an explicit `service` name instead of relying on a guessed default.
- Requires a minimum of Dart 3.10 and Flutter 3.38, enabling support for the latest Objective-C, JNI, and FFI libraries.
- Relaxes version constraints on several dependencies, allowing wider version ranges to be used.
- Split out of `datadog_flutter_plugin` as a federated plugin package.
