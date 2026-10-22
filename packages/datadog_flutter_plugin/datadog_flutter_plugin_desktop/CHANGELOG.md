# Changelog

## 1.0.0-preview.1

### Features

- Initial release of `datadog_flutter_plugin_desktop`.
- Adds support for Windows and Linux desktop platforms, using `dd-sdk-cpp` via FFI bindings.
- Adds a data directory option to control where SDK data is stored on desktop, plus a `getSuggestedDesktopDataDirectory` helper for choosing an OS-appropriate location; by default the current working directory is used, and a warning is logged recommending a dedicated data directory for production apps.
- `DatadogConfiguration` now requires a `service` name to be explicitly set rather than falling back to a default based on the executable name.
- Initial release Windows and Linux support in `datadog_flutter_plugin`.
