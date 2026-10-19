# Changelog

## 1.0.0-preview.1

### Features

- Initial release of `datadog_flutter_plugin_ios`, providing the iOS platform implementation for the Datadog Flutter Plugin as part of a federated plugin architecture.
- Adds macOS support by reusing the shared Darwin implementation from `dd-sdk-ios`.
- Requires a minimum iOS deployment target of iOS 15.
- Requires Dart 3.10 and Flutter 3.38 or newer.
- Configuring Datadog now requires a `service` name to be set explicitly; a default value is no longer inferred automatically.
- Split out of `datadog_flutter_plugin` as a federated plugin package.
