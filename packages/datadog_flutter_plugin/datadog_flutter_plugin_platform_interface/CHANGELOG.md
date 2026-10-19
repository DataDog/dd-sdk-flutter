# Changelog

## 1.0.0-preview.1

### Features

- Initial release of `datadog_flutter_plugin_platform_interface`.
- Raises the minimum supported Dart SDK to 3.10 and Flutter to 3.38, enabling support for newer Objective-C, JNI, and FFI tooling.
- `DatadogConfiguration` now requires a `service` name to be explicitly set rather than falling back to a guessed default.
- RUM APIs now use `operations` naming instead of the deprecated `featureOperations` terminology.
- Adds support for specifying a custom data directory for Desktop targets, along with a `getSuggestedDesktopDataDirectory` helper for getting a sensible default location to store SDK data outside the current working directory.
- Relaxes dependency version constraints, allowing `datadog_flutter_plugin_platform_interface` to work with a wider range of compatible package versions.
- Split out of `datadog_flutter_plugin` as a federated plugin package.
