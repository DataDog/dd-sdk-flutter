The desktop (Windows and Linux) implementation of [`datadog_flutter_plugin`](https://pub.dev/packages/datadog_flutter_plugin).

## Usage

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin), which means
you can use `datadog_flutter_plugin` normally. This package will be automatically
included in your app when you do, so you do not need to add it to your `pubspec.yaml`.

However, if you `import` this package to use any of its APIs directly, you should add it to
your `pubspec.yaml` as usual.

## Data directory

The SDK stores data on disk until it is uploaded. To choose where it is uploaded, 
set `DatadogConfiguration.desktopDataDirectory`. If you don't choose the upload location, the SDK logs a warning and uses a `.datadog`
directory in the process's current working directory, which is only suitable for development.
If the path you set is invalid, the SDK logs an error and does not initialize. This setting
is ignored on other platforms.

`DatadogConfiguration.getSuggestedDesktopDataDirectory` returns a conventional location for
your application: a directory named after the application under `%LOCALAPPDATA%` on Windows
or `$XDG_DATA_HOME` (`~/.local/share` by default) on Linux. Invalid characters in the
application name are replaced. It returns `null` on platforms that don't need a data directory,
or if the location can't be determined.

```dart
final configuration = DatadogConfiguration(
  // ...
  desktopDataDirectory: DatadogConfiguration.getSuggestedDesktopDataDirectory(
    'com.example.myapp',
  ),
);
```
