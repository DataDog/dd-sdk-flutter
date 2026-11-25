A common platform interface for the [`datadog_flutter_plugin`](https://pub.dev/packages/datadog_flutter_plugin) plugin.

This interface helps platform-specific implementations of `datadog_flutter_plugin`
support the same interface.

## Usage

To implement a new platform-specific implementation of `datadog_flutter_plugin`, extend the
relevant platform interface classes, and set the appropriate default `instance` in
your plugin's registration.
