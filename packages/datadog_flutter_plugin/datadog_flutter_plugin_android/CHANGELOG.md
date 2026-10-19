# Changelog

## 1.0.0-preview.1

### Features

- Initial release of `datadog_flutter_plugin_android`.
- The Android implementation of the Datadog Flutter Plugin is now published as its own federated plugin package, allowing Android platform support to be updated and released independently from the main `datadog_flutter_plugin` package.
- Raises the minimum supported versions to Dart 3.10 and Flutter 3.38, enabling upgraded Objective-C, JNI, and FFI library support.
- Configuring Datadog now requires specifying a `service` name; a default is no longer guessed automatically.
- RUM operations are now reported using the `operations` naming instead of the deprecated `featureOperations` terminology.
- Relaxes version constraints on several dependencies, allowing compatibility with a wider range of dependency versions.
- Split out of `datadog_flutter_plugin` as a federated plugin package.
