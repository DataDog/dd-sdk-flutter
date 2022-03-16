<p align="center">
  <img src="dd_logo.png" width="200">
</p>

# Datadog Flutter Plugin

> A Flutter plugin for interacting with Datadog

> ⚠️ This plugin is still in Alpha / Developer Preview. 

## Current Datadog SDK Versions

[//]: # (SDK Table)

iOS SDK | Android SDK | Browser SDK 
:-----: | :---------: | :---------: 
1.9.0 | 1.12.0-alpha2 | ❌

[//]: # (End SDK Table)

## Getting Started

### Get your Client Token and Application Id

For Logs and Tracing, you will need a Datadog [client
token](https://docs.datadoghq.com/account_management/api-app-keys/#client-tokens).
If you are also using RUM, you will need an Application Id as well, which you
can get by creating a [RUM
application](https://docs.datadoghq.com/real_user_monitoring/#getting-started)
under.

### Configure Datadog

First create a configuration object. Each Datadog feature (Logging, Tracing, and
RUM) is configured separately. If you do not pass a configuration for a given
feature, it will be disabled.

```dart
// Determine the user's consent to be tracked
final trackingConsent = ...
final configuration = DdSdkConfiguration(
  clientToken: '<CLIENT_TOKEN>',
  env: '<ENV_NAME>',
  trackingConsent: trackingConsent,
  nativeCrashReportEnabled: true,
  loggingConfiguration: LoggingConfiguration(
    sendNetworkInfo: true,
    printLogsToConsole: true,
  ),
  tracingConfiguration: TracingConfiguration(
    sendNetworkInfo: true,
  ),
  rumConfiguration: RumConfiguration(
    applicationId: '<RUM_APPLICATION_ID',
  )
);
```

### Initialize Datadog

You can initialize Datadog in one of two ways in your `main.dart`.

The simplest way to initialize Datadog is to use `DatadogSdk.runApp`. This will
set up automatic error reporting and resource tracing.

```dart
await DatadogSdk.runApp(configuration, () async {
  runApp(const MyApp());
})
```

Alternatively, you can setup these up on your own. Note that `DatadogSdk.runApp`
calls `WidgetsFlutterBinding.ensureInitialized`. If you are not using
`DatadogSdk.runApp` you will need to call this method prior to calling
`DatadogSdk.instance.initialize`

```dart
runZonedGuarded(() async {
  WidgetsFlutterBinding.ensureInitialized();
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    DatadogSdk.instance.rum?.handleFlutterError(details);
    originalOnError?.call(details);
  };

  await DatadogSdk.instance.initialize(configuration);

  runApp(const MyApp());
}, (e, s) {
  DatadogSdk.instance.rum?.addErrorInfo(
    e.toString(),
    RumErrorSource.source,
    stackTrace: s,
  );
});
```

### Tracking RUM Views

The Datadog Flutter Plugin can automatically track named routes using the
`DatadogNavigationObserver` on your MaterialApp.

```dart
MaterialApp(
  home: HomeScreen(),
  navigatorObservers: [
    DatadogNavigationObserver(),
  ],
);
```

Note, this will only work if you are using **named routes** or supply a name to
`settings` parameter of your `PageRoute`.

Alternately, you can use the `DatadogRouteAwareMixin` in conjunction with the
`DatadogNavigationObserverProvider` to start and stop you RUM views
automatically. Note that `DatadogRouteAwareMixin` recommends you move any logic
from `initState` to `didPush`. Refer to the documentation on those classes for
more details


## Platform Support and Notes

| Android | iOS |  Web | MacOS | Linux | Windows |
| :-----: | :-: | :---: | :-: | :---: | :----: |
|   ✅    | ✅  |  🚧   | ❌  |  ❌   |   ❌   |

### iOS

Your iOS Podfile must have `use_frameworks!` (this is true by default in
Flutter) and must target iOS version >= 11.0.

### Android

On Android, your `minSdkVersion` must be >= 19, and if you are using Kotlin it
should be version >= 1.5.31

# Contributing

Pull requests are welcome. First, open an issue to discuss what you would like
to change. For more information, read the [Contributing
guide](../../CONTRIBUTING.md) in the root repository.

# License

[Apache License, v2.0](LICENSE)