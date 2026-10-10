A common platform interface for the [`datadog_flutter_plugin`](https://pub.dev/packages/datadog_flutter_plugin) plugin.

This interface allows platform-specific implementations of `datadog_flutter_plugin` to ensure
they are supporting the same interface.

## Usage

To implement a new platform-specific implementation of `datadog_flutter_plugin`, extend the
relevant platform interface classes, and ensure you set the appropriate default `instance` in
your plugin's registration.
