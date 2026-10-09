## Overview

Datadog Real User Monitoring (RUM) enables you to visualize and analyze the real-time performance and user journeys of your Flutter application’s individual users.

Datadog RUM SDK versions < 1.4 support monitoring for Flutter 2.8+.
Datadog RUM SDK versions >= 1.4 support monitoring for Flutter 3.0+.
Datadog RUM SDK versions >= 2.6 support monitoring for Flutter 3.19+.
Datadog RUM SDK versions >= 3.0 support monitoring for Flutter 3.27+.
Datadog RUM SDK versions >= 4.0 support monitoring for Flutter 3.38+ (Dart 3.10+).

For complete documentation, see the [official Datadog documentation][11].

## Supported Platforms

| Platform | Support | Notes |
| :------- | :-----: | :---- |
| iOS      | Yes     | iOS 15.0+ |
| Android  | Yes     | `minSdkVersion` 23+ |
| Web      | Yes     | Datadog Browser SDK v7 |
| macOS    | Yes     | macOS 13.0+ |
| Windows  | Yes     | See [Desktop](#desktop-windows-and-linux). |
| Linux    | Yes     | See [Desktop](#desktop-windows-and-linux). |

`datadog_flutter_plugin` is an endorsed federated plugin. The platform packages (`datadog_flutter_plugin_android`, `_ios`, `_web`, and `_desktop`) are included automatically, so you do not need to add them to your `pubspec.yaml`.

## Current Datadog SDK Versions

[//]: # (SDK Table)

| iOS SDK | Android SDK | C++ SDK | Browser SDK |
| :-----: | :---------: | :-----: | :---------: |
| 3.16.0 | 3.13.1 | - | 7.x.x |

[//]: # (End SDK Table)

### iOS

Your iOS Podfile must have `use_frameworks!` (which is true by default in Flutter) and target iOS version >= 15.0.

### macOS

Your app must target macOS version >= 13.0.

### Android

On Android, your `minSdkVersion` must be >= 23, and if you are using Kotlin, it should be version >= 2.1.0.

### Web

On Web, add the following to your `index.html` under your `head` tag:

```html
<script type="text/javascript" crossorigin="anonymous" src="https://www.datadoghq-browser-agent.com/us1/v7/datadog-logs.js"></script>
<script type="text/javascript" crossorigin="anonymous" src="https://www.datadoghq-browser-agent.com/us1/v7/datadog-rum-slim.js"></script>
```

This loads the CDN-delivered Datadog Browser SDKs for Logs and RUM. The synchronous CDN-delivered version of the Datadog Browser SDK is the only version currently supported by the Flutter plugin.

Note that Datadog provides one CDN bundle per site. See the [Browser SDK README](https://github.com/DataDog/browser-sdk/#cdn-bundles) for a list of all site URLs.

See [Flutter Web Support](#web_support) for information on current support for Flutter Web

### Desktop (Windows and Linux)

No additional setup is required beyond a working Flutter desktop toolchain, with one exception: on Linux, the system `libcurl` development package must be installed.

The SDK stores data on disk until it is uploaded. Set `DatadogConfiguration.desktopDataDirectory` to choose where. The path must be absolute and valid for the current platform, and the process must be able to create and write to it. The directory is created if it does not exist, and the SDK assumes exclusive ownership of the files it places there. This setting is ignored on other platforms.

`DatadogConfiguration.getSuggestedDesktopDataDirectory` returns a conventional location for your application: a directory named after the application under `%LOCALAPPDATA%` on Windows, or under `$XDG_DATA_HOME` (`~/.local/share` by default) on Linux. It returns `null` on other platforms or if the location can't be determined.

```dart
final configuration = DatadogConfiguration(
  // ...
  desktopDataDirectory: DatadogConfiguration.getSuggestedDesktopDataDirectory(
    'com.example.myapp',
  ),
);
```

If you don't set `desktopDataDirectory`, the SDK logs a warning and uses a `.datadog` directory in the process's current working directory, which is only suitable for development. If the path you set is invalid, the SDK logs an error and does not initialize.

The following are not currently supported on Windows and Linux:

* `DatadogSdk.attachToExisting` / `DatadogAttachConfiguration`.
* Changing `DatadogSdk.sdkVerbosity` after initialization.
* `DatadogRum.getCurrentSessionId` (always returns `null`), and `DatadogRum.addTiming`, `DatadogRum.addViewLoadingTime`, and `DatadogRum.addFeatureFlagEvaluation`, which do nothing on these platforms.
* Frame build and raster performance metrics.

## Setup

Use the [Datadog Flutter Plugin][1] to set up Log Management or Real User Monitoring (RUM). The setup instructions may vary based on your decision to use Logs, RUM, or both, but most of the setup steps are consistent.

For instructions on how to set up the Datadog Flutter Plugin, see the [official Datadog documentation][11].


### Create configuration object

Create a configuration object for each Datadog feature (such as Logs and RUM) with the following snippet. By not passing a configuration for a given feature, it is disabled.

```dart
// Determine the user's consent to be tracked
final trackingConsent = ...
final configuration = DatadogConfiguration(
  clientToken: '<CLIENT_TOKEN>',
  env: '<ENV_NAME>',
  site: DatadogSite.us1,
  service: '<SERVICE_NAME>',
  nativeCrashReportEnabled: true,
  loggingConfiguration: DatadogLoggingConfiguration(),
  rumConfiguration: DatadogRumConfiguration(
    applicationId: '<RUM_APPLICATION_ID>',
  )
);
```

For more information on available configuration options, see the [DatadogConfiguration object][8] documentation.

### Initialize the library

You can initialize RUM using one of two methods in the `main.dart` file.

1. Use `DatadogSdk.runApp`, which automatically sets up error reporting.

   ```dart
   await DatadogSdk.runApp(configuration, () async {
     runApp(const MyApp());
   })
   ```

2. Alternatively, you can manually set up error tracking and resource tracking. Because `DatadogSdk.runApp` calls `WidgetsFlutterBinding.ensureInitialized`, if you are not using `DatadogSdk.runApp`, you need to call this method prior to calling `DatadogSdk.instance.initialize`.

  ```dart
  WidgetsFlutterBinding.ensureInitialized();
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    DatadogSdk.instance.rum?.handleFlutterError(details);
    originalOnError?.call(details);
  };
  final platformOriginalOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (e, st) {
    DatadogSdk.instance.rum?.addErrorInfo(
      e.toString(),
      RumErrorSource.source,
      stackTrace: st,
    );
    return platformOriginalOnError?.call(e, st) ?? false;
  };
  await DatadogSdk.instance.initialize(configuration);

  runApp(const MyApp());
  ```

### Send Logs

After initializing Datadog with a `DatadogLoggingConfiguration`, you can create an instance of a `DatadogLogger` to send logs to Datadog.

```dart
final logger = DatadogSdk.instance.logs?.createLogger(
  DatadogLoggerConfiguration(
    remoteLogThreshold: LogLevel.warning,
  ),
);
logger?.debug("A debug message.");
logger?.info("Some relevant information?");
logger?.warn("An important warning…");
logger?.error("An error was met!");
```

You can name loggers or customize their service:

```dart
final secondLogger = DatadogSdk.instance.createLogger(
  LoggingConfiguration({
    service: 'my_app.additional_logger',
    name: 'Additional logger'
  })
);

secondLogger.info('Info from my additional logger.');
```

Tags and attributes set on loggers are local to each logger.

### Track RUM views

The Datadog Flutter Plugin can automatically track named routes using the `DatadogNavigationObserver` on your MaterialApp.

```dart
MaterialApp(
  home: HomeScreen(),
  navigatorObservers: [
    DatadogNavigationObserver(DatadogSdk.instance),
  ],
);
```

This works if you are using named routes or if you have supplied a name to the `settings` parameter of your `PageRoute`.

Alternately, you can use the `DatadogRouteAwareMixin` property in conjunction with the `DatadogNavigationObserverProvider` property to start and stop your RUM views automatically. With `DatadogRouteAwareMixin`, move any logic from `initState` to `didPush`.

Note that, by default, `DatadogRouteAwareMixin` uses the name of the widget as the name of the View. However, this **does not work with obfuscated code** as the name of the Widget class is lost during obfuscation. To keep the correct view name, override `rumViewInfo`:

To rename your views or supply custom paths, provide a [`viewInfoExtractor`][10] callback. This function can fall back to the default behavior of the observer by calling `defaultViewInfoExtractor`. For example:

```dart
RumViewInfo? infoExtractor(Route<dynamic> route) {
  var name = route.settings.name;
  if (name == 'my_named_route') {
    return RumViewInfo(
      name: 'MyDifferentName',
      attributes: {'extra_attribute': 'attribute_value'},
    );
  }

  return defaultViewInfoExtractor(route);
}

var observer = DatadogNavigationObserver(
  datadogSdk: DatadogSdk.instance,
  viewInfoExtractor: infoExtractor,
);
```


```dart
class _MyHomeScreenState extends State<MyHomeScreen>
    with RouteAware, DatadogRouteAwareMixin {

  @override
  RumViewInfo get rumViewInfo => RumViewInfo(name: 'MyHomeScreen');
}
```

### Automatic Resource Tracking

You can enable automatic tracking of resources and HTTP calls from your RUM views using the [Datadog Tracking HTTP Client][7] package. Add the package to your `pubspec.yaml`, and add the following to your initialization:

```dart
final configuration = DatadogConfiguration(
  // configuration
  firstPartyHosts: ['example.com'],
)..enableHttpTracking()
```

In order to enable Datadog Distributed Tracing, the `DatadogConfiguration.firstPartyHosts` property in your configuration object must be set to a domain that supports distributed tracing. You can also modify the sampling rate for Datadog distributed tracing by setting the `traceSampleRate` on your `DatadogRumConfiguration`.

## Contributing

Pull requests are welcome. First, open an issue to discuss what you would like to change.

For more information, read the [Contributing guidelines][4].

## License

For more information, see [Apache License, v2.0][5].

[1]: https://pub.dev/packages/datadog_flutter_plugin
[2]: https://app.datadoghq.com/rum/application/create
[3]: https://docs.datadoghq.com/account_management/api-app-keys/#client-tokens
[4]: https://github.com/DataDog/dd-sdk-flutter/blob/main/CONTRIBUTING.md
[5]: https://github.com/DataDog/dd-sdk-flutter/blob/main/LICENSE
[7]: https://pub.dev/packages/datadog_tracking_http_client
[8]: https://pub.dev/documentation/datadog_flutter_plugin/latest/datadog_flutter_plugin/DatadogConfiguration-class.html
[10]: https://pub.dev/documentation/datadog_flutter_plugin/latest/datadog_flutter_plugin/ViewInfoExtractor.html
[11]: https://docs.datadoghq.com/real_user_monitoring/mobile_and_tv_monitoring/setup/flutter/
