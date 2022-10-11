# "Add-To-App" or Hybrid Native + Flutter Applciation Example

This example covers how to use the Datadog Flutter SDK in conjunction with an already existing native application.  This assumes you already have a native iOS or Android Application that is sending data to Datadog, and you have added Flutter to it following Flutter's [Add-to-app documentation](https://docs.flutter.dev/development/add-to-app).

## Native App is Primary and Datadog is Already Initialized -  `attachToExisting`

If you are using an applicaiton that is already using the native Datadog iOS or Datadog Android SDKs, the Flutter SDK can attach to these using the same parameters. In your `main` function, after calling `WidgetsFlutterBinding.ensureInitialized`, call `DatadogSdk.instance.attachToExisting`. You can optionally add a LoggingConfiguraiton to this call, which will automatically create a global logger and attach it to `DatadogSdk.logs`.

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  DatadogSdk.instance.attachToExising();

  runApp(MyApp());
}
```

### Caveats

* The 'source' of the data coming from these Hybrid apps will always be the Native platform, no matter whether the event was sent from the Native SDK or the Flutter SDK.

## Flutter App is Primary - use Datadog as Normal

If you are primarily using Flutter and only occasionally need to access the Native Datadog SDK from a few views, you can assume Datadog has already been initialized and use some of its functionality without issue.

/// TODO - Example

### Caveats

* The Datadog Flutter SDK uses its own View, User Action and Resource tracking, so these are disabled when Flutter performs the initialization. You will need to manually track views and user actions in this scenario.

// TODO - iOS and Android Example
