# Changelog

## 1.0.0-preview.1

### Features

- Initial release of `datadog_flutter_plugin_ios`.
- Adds macOS support by reusing the existing iOS implementation, built on `dd-sdk-ios`.
- Raises the minimum supported iOS version to iOS 15.
- Requires a minimum of Dart 3.10 and Flutter 3.38.
- Requires explicitly setting a `service` name when configuring Datadog; the SDK no longer guesses a default value.
- Renames RUM's "Feature Operations" APIs to "Operations" to align with the latest native SDK naming.
- Split out of `datadog_flutter_plugin` as a federated plugin package.
