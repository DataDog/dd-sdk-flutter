# Changelog

## 1.0.0-preview.1

### Features

- Introduces `datadog_flutter_plugin_platform_interface`, the shared platform interface powering the Datadog Flutter Plugin's federated architecture, enabling platform-specific implementations to be released and maintained independently of the main package.
- `DatadogConfiguration` now requires a `service` name to be explicitly set rather than relying on a platform-specific default.
- Raises minimum supported versions to Dart 3.10 and Flutter 3.38, relaxes overly strict dependency version constraints, and updates some dependencies to new major versions, enabling upgrades to newer Objective-C, JNI, and FFI tooling.
- RUM APIs now use the new `operations` naming instead of the previous `featureOperations` terminology, aligning with the native SDKs.
- Desktop platforms can now specify a custom directory for storing SDK data via a new configuration option, with a helper function `getSuggestedDesktopDataDirectory` to get a sane default location outside the current working directory.
- Split out of `datadog_flutter_plugin` as a federated plugin package.
