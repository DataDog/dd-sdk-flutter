# Changelog

## 1.0.0-preview.1

### Features

- Initial release of `datadog_flutter_plugin_desktop`.
- Adds Windows and Linux support for Datadog Flutter, implemented via FFI bindings to `dd-sdk-cpp`.
- Supports configuring where the SDK stores its local data, including a new `getSuggestedDesktopDataDirectory` helper for a sane OS-specific default location; by default, data is stored in the current working directory, with a warning logged recommending a dedicated data directory for production apps.
- Configuring Datadog now requires explicitly setting a `service` name.
- Initial release Windows and Linux support in `datadog_flutter_plugin`.
